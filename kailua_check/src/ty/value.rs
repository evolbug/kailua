use std::fmt;
use std::ops;
use std::borrow::Cow;

use kailua_syntax::{K, Kind, Str};
use diag::CheckResult;
use super::{TypeContext, Lattice, Flags};
use super::{Numbers, Strings, Tables, Function, Functions, Union, TVar, Builtin};
use super::{error_not_sub, error_not_eq};
use super::flags::*;

// basic value types, also used for enumeration and construction
#[derive(Clone)]
pub enum T<'a> {
    Dynamic,                            // ?
    None,                               // (bottom)
    Nil,                                // nil
    Boolean,                            // boolean
    True,                               // true
    False,                              // false
    Numbers(Cow<'a, Numbers>),          // number, ...
    Strings(Cow<'a, Strings>),          // string, ...
    Tables(Cow<'a, Tables>),            // table, ...
    Functions(Cow<'a, Functions>),      // function, ...
    TVar(TVar),                         // type variable
    Builtin(Builtin, Box<T<'a>>),       // builtin types (cannot be nested)
    Union(Cow<'a, Union>),              // union types A | B | ...
}

impl<'a> T<'a> {
    pub fn number()          -> T<'a> { T::Numbers(Cow::Owned(Numbers::All)) }
    pub fn integer()         -> T<'a> { T::Numbers(Cow::Owned(Numbers::Int)) }
    pub fn int(v: i32)       -> T<'a> { T::Numbers(Cow::Owned(Numbers::One(v))) }
    pub fn string()          -> T<'a> { T::Strings(Cow::Owned(Strings::All)) }
    pub fn str(s: Str)       -> T<'a> { T::Strings(Cow::Owned(Strings::One(s))) }
    pub fn table()           -> T<'a> { T::Tables(Cow::Owned(Tables::All)) }
    pub fn empty_table()     -> T<'a> { T::Tables(Cow::Owned(Tables::Empty)) }
    pub fn function()        -> T<'a> { T::Functions(Cow::Owned(Functions::All)) }
    pub fn func(f: Function) -> T<'a> { T::Functions(Cow::Owned(Functions::Simple(f))) }

    pub fn ints<I: IntoIterator<Item=i32>>(i: I) -> T<'a> {
        T::Numbers(Cow::Owned(Numbers::Some(i.into_iter().collect())))
    }
    pub fn strs<I: IntoIterator<Item=Str>>(i: I) -> T<'a> {
        T::Strings(Cow::Owned(Strings::Some(i.into_iter().collect())))
    }
    pub fn tuple<I: IntoIterator<Item=Ty>>(i: I) -> T<'a> {
        T::Tables(Cow::Owned(Tables::Tuple(i.into_iter().collect())))
    }
    pub fn record<I: IntoIterator<Item=(Str,Ty)>>(i: I) -> T<'a> {
        T::Tables(Cow::Owned(Tables::Record(i.into_iter().collect())))
    }
    pub fn array(v: Ty) -> T<'a> {
        T::Tables(Cow::Owned(Tables::Array(v)))
    }
    pub fn map(k: Ty, v: Ty) -> T<'a> {
        T::Tables(Cow::Owned(Tables::Map(k, v)))
    }

    pub fn from(kind: &K) -> T<'a> {
        match *kind {
            K::Dynamic           => T::Dynamic,
            K::Nil               => T::Nil,
            K::Boolean           => T::Boolean,
            K::BooleanLit(true)  => T::True,
            K::BooleanLit(false) => T::False,
            K::Number            => T::Numbers(Cow::Owned(Numbers::All)),
            K::Integer           => T::Numbers(Cow::Owned(Numbers::Int)),
            K::IntegerLit(v)     => T::Numbers(Cow::Owned(Numbers::One(v))),
            K::String            => T::Strings(Cow::Owned(Strings::All)),
            K::StringLit(ref s)  => T::Strings(Cow::Owned(Strings::One(s.to_owned()))),
            K::Table             => T::Tables(Cow::Owned(Tables::All)),
            K::Function          => T::Functions(Cow::Owned(Functions::All)),

            K::Union(ref kinds) => {
                assert!(!kinds.is_empty());
                let mut ty = T::from(&kinds[0]);
                for kind in &kinds[1..] {
                    ty = ty | T::from(kind);
                }
                ty
            }
        }
    }

    pub fn flags(&self) -> Flags {
        match *self {
            T::Dynamic => T_DYNAMIC,
            T::None    => T_NONE,
            T::Nil     => T_NIL,
            T::Boolean => T_BOOLEAN,
            T::True    => T_TRUE,
            T::False   => T_FALSE,

            T::Numbers(ref num) => match &**num {
                &Numbers::One(..) | &Numbers::Some(..) | &Numbers::Int => T_INTEGER,
                &Numbers::All => T_NUMBER,
            },
            T::Strings(..) => T_STRING,
            T::Tables(..) => T_TABLE,
            T::Functions(..) => T_FUNCTION,

            T::TVar(..) => T_NONE,
            T::Builtin(_, ref t) => t.flags(),
            T::Union(ref u) => u.flags(),
        }
    }

    pub fn is_none(&self) -> bool {
        match *self {
            T::None => true,
            T::Numbers(ref num) =>
                if let &Numbers::Some(ref set) = &**num { set.is_empty() } else { false },
            T::Strings(ref str) =>
                if let &Strings::Some(ref set) = &**str { set.is_empty() } else { false },
            T::Functions(ref func) =>
                if let &Functions::Multi(ref fs) = &**func { fs.is_empty() } else { false },
            T::Builtin(_, ref t) => t.flags() == T_NONE,
            T::Union(ref u) => u.flags() == T_NONE,
            _ => false,
        }
    }

    pub fn is_dynamic(&self)  -> bool { self.flags().is_dynamic() }
    pub fn is_integral(&self) -> bool { self.flags().is_integral() }
    pub fn is_numeric(&self)  -> bool { self.flags().is_numeric() }
    pub fn is_stringy(&self)  -> bool { self.flags().is_stringy() }
    pub fn is_tabular(&self)  -> bool { self.flags().is_tabular() }
    pub fn is_callable(&self) -> bool { self.flags().is_callable() }

    pub fn has_true(&self) -> bool {
        match *self {
            T::Boolean | T::True => true,
            T::Builtin(_, ref t) => t.has_true(),
            T::Union(ref u) => u.has_true,
            _ => false,
        }
    }

    pub fn has_false(&self) -> bool {
        match *self {
            T::Boolean | T::False => true,
            T::Builtin(_, ref t) => t.has_false(),
            T::Union(ref u) => u.has_false,
            _ => false,
        }
    }

    pub fn has_numbers(&self) -> Option<&Numbers> {
        match *self {
            T::Numbers(ref num) => Some(num),
            T::Builtin(_, ref t) => t.has_numbers(),
            T::Union(ref u) => u.numbers.as_ref(),
            _ => None,
        }
    }

    pub fn has_strings(&self) -> Option<&Strings> {
        match *self {
            T::Strings(ref str) => Some(str),
            T::Builtin(_, ref t) => t.has_strings(),
            T::Union(ref u) => u.strings.as_ref(),
            _ => None,
        }
    }

    pub fn has_tables(&self) -> Option<&Tables> {
        match *self {
            T::Tables(ref tab) => Some(tab),
            T::Builtin(_, ref t) => t.has_tables(),
            T::Union(ref u) => u.tables.as_ref(),
            _ => None,
        }
    }

    pub fn has_functions(&self) -> Option<&Functions> {
        match *self {
            T::Functions(ref func) => Some(func),
            T::Builtin(_, ref t) => t.has_functions(),
            T::Union(ref u) => u.functions.as_ref(),
            _ => None,
        }
    }

    pub fn has_tvar(&self) -> Option<TVar> {
        match *self {
            T::TVar(tv) => Some(tv),
            T::Builtin(_, ref t) => t.has_tvar(),
            T::Union(ref u) => u.tvar,
            _ => None,
        }
    }

    pub fn builtin(&self) -> Option<Builtin> {
        match *self { T::Builtin(b, _) => Some(b), _ => None }
    }

    pub fn as_base(&self) -> &T<'a> {
        match self { &T::Builtin(_, ref t) => &*t, t => t }
    }

    pub fn into_base(self) -> T<'a> {
        match self { T::Builtin(_, t) => *t, t => t }
    }

    // XXX should be in S instead
    pub fn accept(&self, rhs: &T) -> bool {
        let flags = self.flags();
        let rhsflags = rhs.flags();
        if flags & rhsflags != rhsflags { return false; }

        // not covered by flags
        match (rhs.has_numbers(), self.has_numbers()) {
            (Some(r), Some(l)) => { if r.assert_sub(l, &mut ()).is_err() { return false; } }
            (None, Some(_)) => return false,
            (_, None) => {}
        }
        match (rhs.has_strings(), self.has_strings()) {
            (Some(r), Some(l)) => { if r.assert_sub(l, &mut ()).is_err() { return false; } }
            (None, Some(_)) => return false,
            (_, None) => {}
        }

        true
    }

    pub fn into_send(self) -> T<'static> {
        match self {
            T::Dynamic    => T::Dynamic,
            T::None       => T::None,
            T::Nil        => T::Nil,
            T::Boolean    => T::Boolean,
            T::True       => T::True,
            T::False      => T::False,

            T::Numbers(num)    => T::Numbers(Cow::Owned(num.into_owned())),
            T::Strings(str)    => T::Strings(Cow::Owned(str.into_owned())),
            T::Tables(tab)     => T::Tables(Cow::Owned(tab.into_owned())),
            T::Functions(func) => T::Functions(Cow::Owned(func.into_owned())),
            T::TVar(tv)        => T::TVar(tv),

            T::Builtin(b, t) => T::Builtin(b, Box::new(t.into_send())),
            T::Union(u) => T::Union(Cow::Owned(u.into_owned())),
        }
    }
}

impl<'a, 'b> Lattice<T<'b>> for T<'a> {
    type Output = T<'static>;

    fn normalize(self) -> T<'static> {
        match self {
            T::Dynamic    => T::Dynamic,
            T::None       => T::None,
            T::Nil        => T::Nil,
            T::Boolean    => T::Boolean,
            T::True       => T::True,
            T::False      => T::False,

            T::Numbers(num) => {
                if let Some(num) = num.into_owned().normalize() {
                    T::Numbers(Cow::Owned(num))
                } else {
                    T::None
                }
            }

            T::Strings(str) => {
                if let Some(str) = str.into_owned().normalize() {
                    T::Strings(Cow::Owned(str))
                } else {
                    T::None
                }
            }

            T::Tables(tab) => {
                if let Some(tab) = tab.into_owned().normalize() {
                    T::Tables(Cow::Owned(tab))
                } else {
                    T::None
                }
            }

            T::Functions(func) => {
                if let Some(func) = func.into_owned().normalize() {
                    T::Functions(Cow::Owned(func))
                } else {
                    T::None
                }
            }

            T::TVar(tv) => T::TVar(tv),
            T::Builtin(b, t) => T::Builtin(b, t.normalize()),
            T::Union(u) => T::Union(Cow::Owned(u.into_owned())),
        }
    }

    fn union(self, other: T<'b>, ctx: &mut TypeContext) -> T<'static> {
        match (self, other) {
            // built-in types are destructured first unless they point to the same builtin
            (T::Builtin(lb, lhs), T::Builtin(rb, rhs)) =>
                if lb == rb {
                    T::Builtin(lb, lhs.union(rhs, ctx))
                } else {
                    (*lhs).union(*rhs, ctx)
                },
            (T::Builtin(_, lhs), rhs) => (*lhs).union(rhs, ctx),
            (lhs, T::Builtin(_, rhs)) => lhs.union(*rhs, ctx),

            // dynamic eclipses everything else
            (T::Dynamic, _) => T::Dynamic,
            (_, T::Dynamic) => T::Dynamic,

            (T::None, ty) => ty.into_send(),
            (ty, T::None) => ty.into_send(),

            (T::Nil,     T::Nil)     => T::Nil,
            (T::Boolean, T::Boolean) => T::Boolean,
            (T::Boolean, T::True)    => T::Boolean,
            (T::Boolean, T::False)   => T::Boolean,
            (T::True,    T::Boolean) => T::Boolean,
            (T::False,   T::Boolean) => T::Boolean,
            (T::True,    T::True)    => T::True,
            (T::True,    T::False)   => T::Boolean,
            (T::False,   T::True)    => T::Boolean,
            (T::False,   T::False)   => T::False,

            (T::Numbers(a), T::Numbers(b)) => {
                if let Some(num) = a.into_owned().union(b.into_owned(), ctx) {
                    T::Numbers(Cow::Owned(num))
                } else {
                    T::None
                }
            }

            (T::Strings(a), T::Strings(b)) => {
                if let Some(str) = a.into_owned().union(b.into_owned(), ctx) {
                    T::Strings(Cow::Owned(str))
                } else {
                    T::None
                }
            }

            (T::Tables(a), T::Tables(b)) => {
                if let Some(tab) = a.into_owned().union(b.into_owned(), ctx) {
                    T::Tables(Cow::Owned(tab))
                } else {
                    T::None
                }
            }

            (T::Functions(a), T::Functions(b)) => {
                if let Some(func) = a.into_owned().union(b.into_owned(), ctx) {
                    T::Functions(Cow::Owned(func))
                } else {
                    T::None
                }
            }

            (T::TVar(a), T::TVar(b)) => T::TVar(a.union(b, ctx)),

            (a, b) => Union::from(&a).union(Union::from(&b), ctx).simplify(),
        }
    }

    fn intersect(self, other: T<'b>, ctx: &mut TypeContext) -> T<'static> {
        match (self, other) {
            // built-in types are destructured first unless they point to the same builtin
            (T::Builtin(lb, lhs), T::Builtin(rb, rhs)) =>
                if lb == rb {
                    T::Builtin(lb, lhs.intersect(rhs, ctx))
                } else {
                    (*lhs).intersect(*rhs, ctx)
                },
            (T::Builtin(_, lhs), rhs) => (*lhs).intersect(rhs, ctx),
            (lhs, T::Builtin(_, rhs)) => lhs.intersect(*rhs, ctx),

            (T::Dynamic, ty) => ty.into_send(),
            (ty, T::Dynamic) => ty.into_send(),

            (T::None, _) => T::None,
            (_, T::None) => T::None,

            (T::Nil,     T::Nil)     => T::Nil,
            (T::Boolean, T::Boolean) => T::Boolean,
            (T::Boolean, T::True)    => T::True,
            (T::Boolean, T::False)   => T::False,
            (T::True,    T::Boolean) => T::True,
            (T::False,   T::Boolean) => T::False,
            (T::True,    T::True)    => T::True,
            (T::False,   T::False)   => T::False,

            (T::Numbers(a), T::Numbers(b)) => {
                if let Some(num) = a.into_owned().intersect(b.into_owned(), ctx) {
                    T::Numbers(Cow::Owned(num))
                } else {
                    T::None
                }
            }

            (T::Strings(a), T::Strings(b)) => {
                if let Some(str) = a.into_owned().intersect(b.into_owned(), ctx) {
                    T::Strings(Cow::Owned(str))
                } else {
                    T::None
                }
            }

            (T::Tables(a), T::Tables(b)) => {
                if let Some(tab) = a.into_owned().intersect(b.into_owned(), ctx) {
                    T::Tables(Cow::Owned(tab))
                } else {
                    T::None
                }
            }

            (T::Functions(a), T::Functions(b)) => {
                if let Some(func) = a.into_owned().intersect(b.into_owned(), ctx) {
                    T::Functions(Cow::Owned(func))
                } else {
                    T::None
                }
            }

            (T::TVar(a), T::TVar(b)) => T::TVar(a.intersect(b, ctx)),

            (a, T::Union(b)) => Union::from(&a).intersect(b.into_owned(), ctx).simplify(),
            (T::Union(a), b) => a.into_owned().intersect(Union::from(&b), ctx).simplify(),
            (_, _) => T::None,
        }
    }

    fn assert_sub(&self, other: &T<'b>, ctx: &mut TypeContext) -> CheckResult<()> {
        println!("asserting a constraint {:?} <: {:?}", *self, *other);

        let ok = match (self, other) {
            // built-in types are destructured first
            (&T::Builtin(_, ref lhs), &T::Builtin(_, ref rhs)) => return lhs.assert_sub(rhs, ctx),
            (&T::Builtin(_, ref lhs), rhs) => return (**lhs).assert_sub(rhs, ctx),
            (lhs, &T::Builtin(_, ref rhs)) => return lhs.assert_sub(&**rhs, ctx),

            (&T::Dynamic, _) => true,
            (_, &T::Dynamic) => true,

            (&T::None, _) => true,
            (_, &T::None) => false,

            (&T::Nil,     &T::Nil)     => true,
            (&T::Boolean, &T::Boolean) => true,
            (&T::True,    &T::Boolean) => true,
            (&T::True,    &T::True)    => true,
            (&T::False,   &T::Boolean) => true,
            (&T::False,   &T::False)   => true,

            (&T::Numbers(ref a),   &T::Numbers(ref b))   => return a.assert_sub(b, ctx),
            (&T::Strings(ref a),   &T::Strings(ref b))   => return a.assert_sub(b, ctx),
            (&T::Tables(ref a),    &T::Tables(ref b))    => return a.assert_sub(b, ctx),
            (&T::Functions(ref a), &T::Functions(ref b)) => return a.assert_sub(b, ctx),

            (&T::Union(ref a), &T::Union(ref b)) => return a.assert_sub(b, ctx),
            (&T::Union(ref a), b) => {
                // a1 \/ a2 <: b === a1 <: b AND a2 <: b
                return a.visit(|i| i.assert_sub(b, ctx));
            },

            // a <: b1 \/ b2 === a <: b1 OR a <: b2
            (&T::Nil,     &T::Union(ref b)) => b.has_nil,
            (&T::Boolean, &T::Union(ref b)) => b.has_true && b.has_false,
            (&T::True,    &T::Union(ref b)) => b.has_true,
            (&T::False,   &T::Union(ref b)) => b.has_false,

            (&T::Numbers(ref a), &T::Union(ref b)) => {
                if let Some(ref num) = b.numbers { return a.assert_sub(num, ctx); }
                false
            },
            (&T::Strings(ref a), &T::Union(ref b)) => {
                if let Some(ref str) = b.strings { return a.assert_sub(str, ctx); }
                false
            },
            (&T::Tables(ref a), &T::Union(ref b)) => {
                if let Some(ref tab) = b.tables { return a.assert_sub(tab, ctx); }
                false
            },
            (&T::Functions(ref a), &T::Union(ref b)) => {
                if let Some(ref func) = b.functions { return a.assert_sub(func, ctx); }
                false
            },
            // XXX a <: T \/ b === a <: T OR a <: b
            (&T::TVar(_a), &T::Union(ref b)) if b.tvar.is_some() => false,

            (&T::TVar(a), &T::TVar(b)) => return a.assert_sub(&b, ctx),
            (a, &T::TVar(b)) => return ctx.assert_tvar_sup(b, a),
            (&T::TVar(a), b) => return ctx.assert_tvar_sub(a, b),

            (_, _) => false,
        };

        if ok { Ok(()) } else { error_not_sub(self, other) }
    }

    fn assert_eq(&self, other: &T<'b>, ctx: &mut TypeContext) -> CheckResult<()> {
        println!("asserting a constraint {:?} = {:?}", *self, *other);

        let ok = match (self, other) {
            // built-in types are destructured first
            (&T::Builtin(_, ref lhs), &T::Builtin(_, ref rhs)) => return lhs.assert_eq(rhs, ctx),
            (&T::Builtin(_, ref lhs), rhs) => return (**lhs).assert_eq(rhs, ctx),
            (lhs, &T::Builtin(_, ref rhs)) => return lhs.assert_eq(&**rhs, ctx),

            (&T::Dynamic, _) => true,
            (_, &T::Dynamic) => true,

            (&T::None, _) => true,
            (_, &T::None) => false,

            (&T::Nil,     &T::Nil)     => true,
            (&T::Boolean, &T::Boolean) => true,
            (&T::True,    &T::True)    => true,
            (&T::False,   &T::False)   => true,

            (&T::Numbers(ref a),   &T::Numbers(ref b))   => return a.assert_eq(b, ctx),
            (&T::Strings(ref a),   &T::Strings(ref b))   => return a.assert_eq(b, ctx),
            (&T::Tables(ref a),    &T::Tables(ref b))    => return a.assert_eq(b, ctx),
            (&T::Functions(ref a), &T::Functions(ref b)) => return a.assert_eq(b, ctx),

            (&T::TVar(a), &T::TVar(b)) => return a.assert_eq(&b, ctx),
            (a, &T::TVar(b)) => return ctx.assert_tvar_eq(b, a),
            (&T::TVar(a), b) => return ctx.assert_tvar_eq(a, b),

            (&T::Union(ref a), &T::Union(ref b)) => return a.assert_eq(b, ctx),
            (&T::Union(ref _a), _b) => unimplemented!(), // XXX for now
            (_a, &T::Union(ref _b)) => unimplemented!(), // XXX for now

            (_, _) => false,
        };

        if ok { Ok(()) } else { error_not_eq(self, other) }
    }
}

impl<'a, 'b> ops::BitOr<T<'b>> for T<'a> {
    type Output = T<'static>;
    fn bitor(self, rhs: T<'b>) -> T<'static> { self.union(rhs, &mut ()) }
}

impl<'a, 'b> ops::BitAnd<T<'b>> for T<'a> {
    type Output = T<'static>;
    fn bitand(self, rhs: T<'b>) -> T<'static> { self.intersect(rhs, &mut ()) }
}

// not intended to be complete equality, but enough for testing
impl<'a, 'b> PartialEq<T<'b>> for T<'a> {
    fn eq(&self, other: &T<'b>) -> bool {
        match (self, other) {
            (&T::Dynamic, &T::Dynamic) => true,
            (&T::None,    &T::None)    => true,
            (&T::Nil,     &T::Nil)     => true,
            (&T::Boolean, &T::Boolean) => true,
            (&T::True,    &T::True)    => true,
            (&T::False,   &T::False)   => true,

            (&T::Numbers(ref a),   &T::Numbers(ref b))   => *a == *b,
            (&T::Strings(ref a),   &T::Strings(ref b))   => *a == *b,
            (&T::Tables(ref a),    &T::Tables(ref b))    => *a == *b,
            (&T::Functions(ref a), &T::Functions(ref b)) => *a == *b,
            (&T::TVar(a),          &T::TVar(b))          => a == b,
            (&T::Builtin(ba, _),   &T::Builtin(bb, _))   => ba == bb,
            (&T::Union(ref a),     &T::Union(ref b))     => a == b,

            (_, _) => false,
        }
    }
}

impl<'a> fmt::Debug for T<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            T::Dynamic => write!(f, "?"),
            T::None    => write!(f, "<bottom>"),
            T::Nil     => write!(f, "nil"),
            T::Boolean => write!(f, "boolean"),
            T::True    => write!(f, "true"),
            T::False   => write!(f, "false"),

            T::Numbers(ref num)    => fmt::Debug::fmt(num, f),
            T::Strings(ref str)    => fmt::Debug::fmt(str, f),
            T::Tables(ref tab)     => fmt::Debug::fmt(tab, f),
            T::Functions(ref func) => fmt::Debug::fmt(func, f),
            T::TVar(tv)            => write!(f, "<#{}>", tv.0),
            T::Builtin(b, ref t)   => write!(f, "{:?} (= {})", *t, b.name()),
            T::Union(ref u)        => fmt::Debug::fmt(u, f),
        }
    }
}

impl<'a> From<T<'a>> for Union { fn from(x: T<'a>) -> Union { Union::from(&x) } }

impl<'a> From<K> for T<'a> { fn from(x: K) -> T<'a> { T::from(&x) } }

pub type Ty = Box<T<'static>>;

impl From<Kind> for Ty { fn from(x: Kind) -> Ty { Box::new(From::from(*x)) } }

#[cfg(test)] 
mod tests {
    use kailua_syntax::Str;
    use ty::{Lattice, TypeContext};
    use super::*;

    macro_rules! hash {
        ($($k:ident = $v:expr),*) => (vec![$((s(stringify!($k)), $v)),*])
    }

    fn b<T>(x: T) -> Box<T> { Box::new(x) }
    fn s(x: &str) -> Str { Str::from(x.as_bytes().to_owned()) }

    #[test]
    fn test_lattice() {
        macro_rules! check {
            ($l:expr, $r:expr; $u:expr, $i:expr) => ({
                let left = $l;
                let right = $r;
                let union = $u;
                let intersect = $i;
                let actualunion = left.clone().union(right.clone(), &mut ());
                if actualunion != union {
                    panic!("{:?} | {:?} = expected {:?}, actual {:?}",
                           left, right, union, actualunion);
                }
                let actualintersect = left.clone().intersect(right.clone(), &mut ());
                if actualintersect != intersect {
                    panic!("{:?} & {:?} = expected {:?}, actual {:?}",
                           left, right, intersect, actualintersect);
                }
            })
        }

        // dynamic vs. everything else
        check!(T::Dynamic, T::Dynamic; T::Dynamic, T::Dynamic);
        check!(T::Dynamic, T::integer(); T::Dynamic, T::integer());
        check!(T::tuple(vec![b(T::integer()), b(T::Boolean)]), T::Dynamic;
               T::Dynamic, T::tuple(vec![b(T::integer()), b(T::Boolean)]));

        // integer literals
        check!(T::integer(), T::number(); T::number(), T::integer());
        check!(T::number(), T::integer(); T::number(), T::integer());
        check!(T::number(), T::number(); T::number(), T::number());
        check!(T::integer(), T::integer(); T::integer(), T::integer());
        check!(T::int(3), T::int(3); T::int(3), T::int(3));
        check!(T::int(3), T::number(); T::number(), T::int(3));
        check!(T::integer(), T::int(3); T::integer(), T::int(3));
        check!(T::int(3), T::int(4); T::ints(vec![3, 4]), T::None);
        check!(T::ints(vec![3, 4]), T::int(3);
               T::ints(vec![3, 4]), T::int(3));
        check!(T::int(5), T::ints(vec![3, 4]);
               T::ints(vec![3, 4, 5]), T::None);
        check!(T::ints(vec![3, 4]), T::ints(vec![5, 4, 7]);
               T::ints(vec![3, 4, 5, 7]), T::int(4));
        check!(T::ints(vec![3, 4, 5]), T::ints(vec![2, 3, 4]);
               T::ints(vec![2, 3, 4, 5]), T::ints(vec![3, 4]));

        // string literals
        check!(T::string(), T::str(s("hello")); T::string(), T::str(s("hello")));
        check!(T::str(s("hello")), T::string(); T::string(), T::str(s("hello")));
        check!(T::str(s("hello")), T::str(s("hello"));
               T::str(s("hello")), T::str(s("hello")));
        check!(T::str(s("hello")), T::str(s("goodbye"));
               T::strs(vec![s("hello"), s("goodbye")]), T::None);
        check!(T::str(s("hello")), T::strs(vec![s("goodbye")]);
               T::strs(vec![s("hello"), s("goodbye")]), T::None);
        check!(T::strs(vec![s("hello"), s("goodbye")]), T::str(s("goodbye"));
               T::strs(vec![s("hello"), s("goodbye")]), T::str(s("goodbye")));
        check!(T::strs(vec![s("hello"), s("goodbye")]),
               T::strs(vec![s("what"), s("goodbye")]);
               T::strs(vec![s("hello"), s("goodbye"), s("what")]),
               T::str(s("goodbye")));
        check!(T::strs(vec![s("a"), s("b"), s("c")]),
               T::strs(vec![s("b"), s("c"), s("d")]);
               T::strs(vec![s("a"), s("b"), s("c"), s("d")]),
               T::strs(vec![s("b"), s("c")]));

        // tables
        check!(T::table(), T::array(b(T::integer())); T::table(), T::array(b(T::integer())));
        check!(T::array(b(T::integer())), T::array(b(T::integer()));
               T::array(b(T::integer())), T::array(b(T::integer())));
        check!(T::array(b(T::int(3))), T::array(b(T::int(4)));
               T::array(b(T::ints(vec![3, 4]))), T::array(b(T::None)));
        check!(T::tuple(vec![b(T::integer()), b(T::string())]),
               T::tuple(vec![b(T::number()), b(T::Dynamic), b(T::Boolean)]);
               T::tuple(vec![b(T::number()), b(T::Dynamic), b(T::Boolean | T::Nil)]),
               T::tuple(vec![b(T::integer()), b(T::string())]));
        check!(T::tuple(vec![b(T::integer()), b(T::string())]),
               T::tuple(vec![b(T::number()), b(T::Boolean), b(T::Dynamic)]);
               T::tuple(vec![b(T::number()), b(T::string() | T::Boolean), b(T::Dynamic)]),
               T::empty_table()); // boolean & string = _|_, so no way to reconcile
        check!(T::record(hash![foo=b(T::integer()), bar=b(T::string())]),
               T::record(hash![quux=b(T::Boolean)]);
               T::record(hash![foo=b(T::integer()), bar=b(T::string()), quux=b(T::Boolean)]),
               T::empty_table());
        check!(T::record(hash![foo=b(T::int(3)), bar=b(T::string())]),
               T::record(hash![foo=b(T::int(4))]);
               T::record(hash![foo=b(T::ints(vec![3, 4])), bar=b(T::string())]),
               T::empty_table());
        check!(T::record(hash![foo=b(T::integer()), bar=b(T::number()),
                                    quux=b(T::array(b(T::Dynamic)))]),
               T::record(hash![foo=b(T::number()), bar=b(T::string()),
                                    quux=b(T::array(b(T::Boolean)))]);
               T::record(hash![foo=b(T::number()), bar=b(T::number() | T::string()),
                                    quux=b(T::array(b(T::Dynamic)))]),
               T::record(hash![foo=b(T::integer()),
                                    quux=b(T::array(b(T::Boolean)))]));
        check!(T::record(hash![foo=b(T::int(3)), bar=b(T::number())]),
               T::map(b(T::string()), b(T::integer()));
               T::map(b(T::string()), b(T::number())),
               T::record(hash![foo=b(T::int(3)), bar=b(T::integer())]));
        check!(T::map(b(T::str(s("wat"))), b(T::integer())),
               T::map(b(T::string()), b(T::int(42)));
               T::map(b(T::string()), b(T::integer())),
               T::map(b(T::str(s("wat"))), b(T::int(42))));
        check!(T::array(b(T::number())), T::map(b(T::Dynamic), b(T::integer()));
               T::map(b(T::Dynamic), b(T::number())), T::array(b(T::integer())));
        check!(T::empty_table(), T::array(b(T::integer()));
               T::array(b(T::integer())), T::empty_table());

        // general unions
        check!(T::True, T::False; T::Boolean, T::None);
        check!(T::int(3) | T::Nil, T::int(4) | T::Nil;
               T::ints(vec![3, 4]) | T::Nil, T::Nil);
        check!(T::ints(vec![3, 5]) | T::Nil, T::int(4) | T::string();
               T::string() | T::ints(vec![3, 4, 5]) | T::Nil, T::None);
        check!(T::int(3) | T::string(), T::str(s("wat")) | T::int(4);
               T::ints(vec![3, 4]) | T::string(), T::str(s("wat")));
        check!(T::array(b(T::integer())), T::tuple(vec![b(T::string())]);
               T::map(b(T::integer()), b(T::integer() | T::string())), T::empty_table());
        //assert_eq!(T::map(b(T::string()), b(T::integer())),
        //           T::map(b(T::string()), b(T::integer() | T::Nil)));
    }

    #[test]
    fn test_sub() {
        use env::Context;

        let mut ctx = Context::new();

        {
            let v1 = ctx.gen_tvar();
            // v1 <: integer
            assert_eq!(T::TVar(v1).assert_sub(&T::integer(), &mut ctx), Ok(()));
            // v1 <: integer
            assert_eq!(T::TVar(v1).assert_sub(&T::integer(), &mut ctx), Ok(()));
            // v1 <: integer AND v1 <: string (!)
            assert!(T::TVar(v1).assert_sub(&T::string(), &mut ctx).is_err());
        }

        {
            let v1 = ctx.gen_tvar();
            let v2 = ctx.gen_tvar();
            // v1 <: v2
            assert_eq!(T::TVar(v1).assert_sub(&T::TVar(v2), &mut ctx), Ok(()));
            // v1 <: v2 <: string
            assert_eq!(T::TVar(v2).assert_sub(&T::string(), &mut ctx), Ok(()));
            // v1 <: v2 <: string AND v1 <: integer (!)
            assert!(T::TVar(v1).assert_sub(&T::integer(), &mut ctx).is_err());
        }

        {
            let v1 = ctx.gen_tvar();
            let v2 = ctx.gen_tvar();
            let t1 = T::record(hash![a=b(T::integer()), b=b(T::TVar(v1))]);
            let t2 = T::record(hash![a=b(T::TVar(v2)), b=b(T::string()), c=b(T::Boolean)]);
            // {a=integer, b=v1} <: {a=v2, b=string, c=boolean}
            assert_eq!(t1.assert_sub(&t2, &mut ctx), Ok(()));
            // ... AND v1 <: string
            assert_eq!(T::TVar(v1).assert_sub(&T::string(), &mut ctx), Ok(()));
            // ... AND v1 <: string AND v2 :> integer
            assert_eq!(T::integer().assert_sub(&T::TVar(v2), &mut ctx), Ok(()));
            // {a=integer, b=v1} = {a=v2, b=string, c=boolean} (!)
            assert!(t1.assert_eq(&t2, &mut ctx).is_err());
        }
    }
}
