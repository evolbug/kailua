-- Basic tests for the Kailua type checker.

--8<-- funccall-nil
local p
p() --@< Error: Tried to call a non-function `nil`
--! error

--8<-- funccall-func
local function p() end
p()
--! ok

--8<-- funccall-func-too-many-args
local function p() end
p(3) --@< Error: The type `function() --> ()` cannot be called
     --@^ Cause: First function argument `3` is not a subtype of `nil`
--! error

--8<-- funccall-func-too-less-args-1 -- feature:!no_implicit_func_sig
local function p(x)
    x = x + 1
end
p()
--! ok

--8<-- funccall-func-too-less-args-2
local function p(x) --: integer
    x = x + 1
end
p()
--! ok

--8<-- funccall-func-too-less-args-3
local function p(x) --: integer?
    x = x + 1 --@< Error: Cannot apply + operator to `integer?` and `1`
              --@^ Cause: `integer?` is not a subtype of `number`
              --@^^ Error: Cannot assign `number` into `integer?`
              --@^^^ Note: The other type originates here
end
p()
--! error

--8<-- funccall-func-too-less-args-4
local function p(x) --: integer!
    x = x + 1
end
p() --@< Error: The type `function(integer!) --> ()` cannot be called
    --@^ Cause: First function argument `nil` is not a subtype of `integer!`
--! error

--8<-- funccall-var-outside-of-scope-1
local c
if c then
    local p
end
p() --@< Error: Global or local variable `p` is not defined
--! error

--8<-- funccall-var-outside-of-scope-2
local c = true
if c then
    local p
end
p() --@< Error: Global or local variable `p` is not defined
--! error

--8<-- funccall-var-outside-of-scope-3
local c = false
if c then
    local p
end
p() --@< Error: Global or local variable `p` is not defined
--! error

--8<-- funccall-var-outside-of-scope-4
local c --: boolean?
if c then
    local p
end
p() --@< Error: Global or local variable `p` is not defined
--! error

--8<-- funccall-integer-or-nil-1
local c, p
if c then p = 4 end
p() --@< Error: Tried to call a non-function `nil`
--! error

--8<-- funccall-integer-or-nil-2
local c --: boolean?
local p
if c then p = 4 end
p() --@< Error: Tried to call a non-function `4`
--! error

--8<-- funccall-undefined
p() --@< Error: Global or local variable `p` is not defined
--! error

--8<-- funccall-dynamic
--# assume p: WHATEVER
p()
--! ok

--8<-- methodcall-dynamic
--# assume s: WHATEVER
local p = s:find('hello')
--! ok

--8<-- add-number-integer
--# assume p: number
local x = p + 3
--! ok

--8<-- add-number-string
--# assume p: number
local x = p + 'foo' --@< Error: Cannot apply + operator to `number` and `"foo"`
                    --@^ Cause: `"foo"` is not a subtype of `number`
--! error

--8<-- add-number-func
local function p() end
local x = p + 'foo' --@< Error: Cannot apply + operator to `function() --> ()` and `"foo"`
                    --@^ Cause: `function() --> ()` is not a subtype of `number`
                    --@^^ Cause: `"foo"` is not a subtype of `number`
--! error

--8<-- arith-integer
--# assume p: integer
p = 2 + 3 * (4 + 5 - 6) % 7
--! ok

--8<-- arith-integer-implicit-nil
--# assume p: integer
local q = p + p --: integer!
--! ok

--8<-- arith-integer-explicit-nil
--# assume p: integer?
local p = p + p --: integer! --@< Error: Cannot apply + operator to `integer?` and `integer?`
                             --@^ Cause: `integer?` is not a subtype of `number`
                             --@^^ Cause: `integer?` is not a subtype of `number`
                             --@^^^ Error: Cannot assign `number` into `integer!`
                             --@^^^^ Note: The other type originates here
--! error

--8<-- arith-integer-no-nil
--# assume p: integer!
local p = p + p --: integer!
--! ok

--8<-- lt-number-integer-1
--# assume p: number
local x = p < 3
--! ok

--8<-- lt-number-integer-2
--# assume p: integer
local x = 2.17 < p
--! ok

--8<-- lt-integer-number-1
--# assume p: integer
local x = p < 3.14
--! ok

--8<-- lt-integer-number-2
--# assume p: number
local x = 2 < p
--! ok

--8<-- lt-string-string
--# assume p: string
local x = p < 'string'
--! ok

--8<-- lt-string-number
--# assume p: string
local x = p < 3.14 --@< Error: Operands `string` and `number` to < operator should be both numbers or both strings
--! error

--8<-- lt-string-or-number
--# assume p: string|number
local x = p < 3.14 --@< Error: Operand `(number|string)` to < operator should be either numbers or strings but not both
--! error

--8<-- lt-string-or-number-both
--# assume p: 'hello'|number
--# assume q: string|integer
local x = p < q --@< Error: Operand `(number|"hello")` to < operator should be either numbers or strings but not both
                --@^ Error: Operand `(integer|string)` to < operator should be either numbers or strings but not both
--! error

--8<-- lt-func-number
local function p() end
local x = p < 3.14 --@< Error: Cannot apply < operator to `function() --> ()` and `number`
--! error

--8<-- lt-error -- exact
local x = f() --@< Error: Global or local variable `f` is not defined
local y = 3 < x
--! error

--8<-- unknown-type
--# assume p: unknown_type --@< Error: Type `unknown_type` is not defined
--! error

--8<-- add-integer-integer
local p = 3 + 4
--! ok

--8<-- add-integer-string
local p = 3 + 'foo' --@< Error: Cannot apply + operator to `3` and `"foo"`
                    --@^ Cause: `"foo"` is not a subtype of `number`
--! error

--8<-- add-boolean-integer
local p = true + 7 --@< Error: Cannot apply + operator to `true` and `7`
                   --@^ Cause: `true` is not a subtype of `number`
--! error

--8<-- index-empty-with-integer
local p = ({})[3] --@< Error: Cannot index `{}` with `3`
--! error

--8<-- index-intrec-with-integer
local p = ({[3] = 4})[3]
--! ok

--8<-- index-intrec-with-integer-no-key
local p = ({[2] = 4})[3] --@< Error: Cannot index `{2 = 4}` with `3`
--! error

--8<-- index-map-with-integer
local t = {[3] = 4, [8] = 5} --: map<integer, integer>
local p = t[3]
--! ok

--8<-- index-map-with-integer-type
local t = {[3] = 'four', [8] = 'five'} --: map<integer, string>
local p = t[3] + 3 --@< Error: Cannot apply + operator to `string` and `3`
                   --@^ Cause: `string` is not a subtype of `number`
--! error

--8<-- index-map-with-integer-no-key
local t = {[2] = 4, [8] = 5} --: map<integer, integer>
local p = t[3]
--! ok

--8<-- index-map-with-integer-no-subtype
local t = {[2] = 4, [8] = 5} --: map<integer, integer>
local p = t.string --@< Error: Cannot index `map<integer, integer>` with `"string"`
--! error

--8<-- index-empty-with-name
local p = ({}).a --@< Error: Cannot index `{}` with `"a"`
--! error

--8<-- index-rec-with-name
local p = ({a = 4}).a
--! ok

--8<-- index-rec-with-name-no-key
local p = ({a = 4}).b --@< Error: Cannot index `{a = 4}` with `"b"`
--! error

--8<-- index-rec-with-string
--# assume x: string
local p = ({a = 4})[x]
--@^ Error: Cannot index `{a = 4}` with index `string` that cannot be resolved ahead of time
--! error

--8<-- index-rec-with-weird-string
--# assume x: 'not ice'
local p = ({['not ice'] = 4})[x]
--! ok

--8<-- index-rec-with-weird-string-error
--# assume x: 'ice'
local p = ({['not ice'] = 4})[x] --@< Error: Cannot index `{`not ice` = 4}` with `"ice"`
--! error

--8<-- methodcall-empty
local p = ({}):hello() --@< Error: Cannot index `{}` with `"hello"`
--! error

--8<-- methodcall-rec-1 -- feature:no_implicit_func_sig
local x = {hello = function(a) end}
--@^ Error: The type for this argument in the anonymous function is missing but couldn't be inferred from the calls
local p = x:hello()
--! error

--8<-- methodcall-rec-1-type-1 -- feature:no_implicit_func_sig
-- TODO should this be inferrable?
local x = {hello = function(a) end} --: {hello = function(table)}
--@^ Error: The type for this argument in the anonymous function is missing but couldn't be inferred from the calls
local p = x:hello()
--! error

--8<-- methodcall-rec-1-type-2
local x = {}
--v function(a: table)
local function hello(a) end
x.hello = hello
local p = x:hello()
--! ok

--8<-- methodcall-rec-2
local x = {hello = --v function(a: table!, b: integer!)
                   function(a, b) end}
local p = x:hello() --@< Error: The type `function(table!, integer!) --> ()` cannot be called
                    --@^ Cause: Second function argument `nil` is not a subtype of `integer!`
--! error

--8<-- methodcall-rec-3
local x = {hello = --v function(a: table!, b: integer!)
                   function(a, b) end}
local p = x:hello(4)
--! ok

--8<-- methodcall-rec-4
local x = {hello = --v function(a: table!, b: integer!)
                   function(a, b) end}
local p = x:hello('string') --@< Error: The type `function(table!, integer!) --> ()` cannot be called
                            --@^ Cause: Second function argument `"string"` is not a subtype of `integer!`
--! error

--8<-- methodcall-rec-5
local x = {hello = function() end}
local p = x:hello() --@< Error: The type `function() --> ()` cannot be called
                    --@^ Cause: First function argument `{hello = function() --> ()}` is not a subtype of `nil`
--! error

--8<-- methodcall-integer
local s = (42):char() --@< Error: Tried to index a non-table type `42`
--! error

--8<-- index-func
local p = (function() end)[3] --@< Error: Tried to index a non-table type `function() --> ()`
--! error

--8<-- delayed-init-nil
local f
f = nil
--! ok

--8<-- delayed-init-string
local f
f = 'hello?'
--! ok

--8<-- reinit-nil-string-implicit
local f = nil
f = 'hello?' --@< Error: Cannot assign `"hello?"` into `nil`
             --@^ Note: The other type originates here
--! error

--8<-- reinit-nil-string-explicit
local f = nil --: string
f = 'hello?'
--! ok

--8<-- reinit-string-nil-implicit
local x = 'hello?' --: string
local f = x
f = nil
--! ok

--8<-- reinit-string-nil-explicit
local x = 'hello?' --: string
local f = x --: string
f = nil
--! ok

--8<-- reinit-func-func
local f = function() end
f = function() return 54 end --@< Error: Cannot assign `function() --> 54` into `function() --> ()`
                             --@^ Note: The other type originates here
--! error

--8<-- reinit-func-table
local f = function() end
f = {54, 49} --@< Error: Cannot assign `{54, 49}` into `function() --> ()`
             --@^ Note: The other type originates here
--! error

--8<-- assume-rec
local f = function() end
--# assume f: {index = integer}
local p = f.index
--! ok

--8<-- assume-table
local f = function() end
--# assume f: table
local p = f.index --@< Error: Cannot index `table` without downcasting
--! error

--8<-- conjunctive-lhs-1
local a = ('string' and 53) + 42
--! ok

--8<-- conjunctive-lhs-1
local a = (53 and 'string') + 42 --@< Error: Cannot apply + operator to `"string"` and `42`
                                 --@^ Cause: `"string"` is not a subtype of `number`
--! error

--8<-- conjunctive-rhs-1
local a = (false and 'string') + 42 --@< Error: Cannot apply + operator to `false` and `42`
                                    --@^ Cause: `false` is not a subtype of `number`
--! error

--8<-- conjunctive-rhs-2
local a = (false and 53) + 42 --@< Error: Cannot apply + operator to `false` and `42`
                              --@^ Cause: `false` is not a subtype of `number`
--! error

--8<-- conjunctive-type-erasure
--# assume x: nil | boolean
local a = x and 53 --: integer | nil | false
--! ok

--8<-- disjunctive-lhs-1
local a = (53 or 'string') + 42
--! ok

--8<-- disjunctive-lhs-2
local a = (53 or nil) + 42
--! ok

--8<-- disjunctive-rhs-1
local a = (nil or 'string') + 42 --@< Error: Cannot apply + operator to `"string"` and `42`
                                 --@^ Cause: `"string"` is not a subtype of `number`
--! error

--8<-- disjunctive-rhs-2
local a = (nil or 53) + 42
--! ok

--8<-- disjunctive-type-erasure
--# assume x: integer?
--# assume y: integer | boolean
local a = (x or 53) + 42
local b = y or 53 --: integer | true
--! ok

--8<-- disjunctive-type-erasure-table
--# assume x: {a = string, b = integer}?
local x = x or {} --: {a = string, b = integer}!
--! ok

--8<-- conjunctive-lhs-dynamic
--# assume p: WHATEVER
local a = (p and 'foo') + 54
--! ok

--8<-- conjunctive-rhs-dynamic
--# assume p: WHATEVER
local a = ('foo' and p) + 54
--! ok

--8<-- disjunctive-lhs-dynamic
--# assume p: WHATEVER
local a = (p or 'foo') + 54
--! ok

--8<-- disjunctive-rhs-dynamic
--# assume p: WHATEVER
local a = ('foo' or p) + 54
--! ok

--8<-- ad-hoc-conditional-1
--# assume x: boolean
local a = x and 54 or 42 --: integer
--! ok

--8<-- ad-hoc-conditional-2
--# assume x: integer|string|boolean|table
local a = x and 54 or 42 --: integer
--! ok

--8<-- cat-string-or-number
--# assume p: string | number
local q = p .. 3
--! ok

--8<-- add-string-or-number
--# assume p: string | number
local q = p + 3 --@< Error: Cannot apply + operator to `(number|string)` and `3`
                --@^ Cause: `(number|string)` is not a subtype of `number`
--! error

--8<-- cat-string-or-boolean
--# assume p: string | boolean
local q = p .. 3 --@< Error: Cannot apply .. operator to `(boolean|string)` and `3`
                 --@^ Cause: `(boolean|string)` is not a subtype of `(number|string)`
--! error

--8<-- cat-string-lit-1
--# assume p: 'a'
--# assume q: 'b'
--# assume r: 'ab'
r = p .. q
--! ok

--8<-- cat-string-lit-2
--# assume r: 'ab'
r = 'a' .. 'b'
--! ok

--8<-- cat-string-lit-3
--# assume r: 'ab'
local p = 'a' --: string
r = p .. 'b' --@< Error: Cannot assign `string` into `"ab"`
             --@^ Note: The other type originates here
--! error

--8<-- var-integer-literal
local x
--# assume x: 3
x = 3
--! ok

--8<-- var-integer-literals-1
local x
--# assume x: 3 | 4
x = 3
--! ok

--8<-- var-integer-literals-2
local x
--# assume x: 4 | 5
x = 3 --@< Error: Cannot assign `3` into `(4|5)`
      --@^ Note: The other type originates here
--! error

--8<-- add-sub-mul-mod-integer-integer
local x, y, z
--# assume x: integer
--# assume y: integer
--# assume z: integer
z = x + y
z = x - y
z = x * y
z = x % y
--! ok

--8<-- div-integer-integer
local x, y, z
--# assume x: integer
--# assume y: integer
--# assume z: integer
z = x / y --@< Error: Cannot assign `number` into `integer`
          --@^ Note: The other type originates here
--! error

--8<-- add-integer-integer-is-integer
local p
--# assume p: integer
p = 3 + 4
--! ok

--8<-- add-number-integer-is-not-integer
local p
--# assume p: integer
p = 3.1 + 4 --@< Error: Cannot assign `number` into `integer`
            --@^ Note: The other type originates here
--! error

--8<-- add-dynamic-integer
local p, q
--# assume p: WHATEVER
--# assume q: integer
q = p + 3
--! ok

--8<-- add-dynamic-number-is-not-integer
local p, q
--# assume p: WHATEVER
--# assume q: integer
q = p + 3.5 --@< Error: Cannot assign `number` into `integer`
            --@^ Note: The other type originates here
--! error

--8<-- add-dynamic-number-is-number
local p, q
--# assume p: WHATEVER
--# assume q: number
q = p + 3.5
--! ok

--8<-- add-dynamic-dynamic-1
local p, q
--# assume p: WHATEVER
--# assume q: number
q = p + p
--! ok

--8<-- add-dynamic-dynamic-2
local p, q
--# assume p: WHATEVER
--# assume q: integer
q = p + p --@< Error: Cannot assign `number` into `integer`
          --@^ Note: The other type originates here
--! error

--8<-- len-table
local a = 3 + #{1, 2, 3}
--! ok

--8<-- len-string
local a = 3 + #'heck'
--! ok

--8<-- len-integer
local a = 3 + #4 --@< Error: Cannot apply # operator to `4`
                 --@^ Cause: `4` is not a subtype of `(string|table)`
--! error

--8<-- for
--# assume a: integer
for i = 1, 9 do a = i end
--! ok

--8<-- for-step
--# assume a: integer
for i = 1, 9, 2 do a = i end
--! ok

--8<-- for-non-integer
--# assume a: integer
for i = 1.1, 9 do
    a = i --@< Error: Cannot assign `number` into `integer`
          --@^ Note: The other type originates here
end
--! error

--8<-- for-non-integer-step
--# assume a: integer
for i = 1, 9, 2.1 do
    a = i --@< Error: Cannot assign `number` into `integer`
          --@^ Note: The other type originates here
end
--! error

--8<-- func-never-returns
function f()
    while true do end
end
--! ok

--8<-- func-varargs -- feature:no_implicit_func_sig
--@v-vvv Error: The type for variadic arguments in the anonymous function is missing but couldn't be inferred from the calls
function a(...)
    return ...
end
--! error

--8<-- func-varargs-type
--v function(...: any) --> (any...)
function a(...)
    return ...
end
--! ok

--8<-- func-no-varargs
function a()
    return ... --@< Error: Variadic arguments do not exist in the innermost function
end
--! error

--8<-- func-nested-varargs
--v function(...: any) --> function() --> (any...)
function a(...)
    return function()
        return ... --@< Error: Variadic arguments do not exist in the innermost function
    end
end
--! error

--8<-- func-hint
--v function(a: function(integer, integer) --> integer)
function p(a) end

p(function(x, y)
    return x + y
end)
--! ok

--8<-- func-hint-not-func -- feature:no_implicit_func_sig
--v function(a: string)
function p(a) end

p(function(x) end)
--@^ Error: The type for this argument in the anonymous function is missing but couldn't be inferred from the calls
--@^^ Error: The type `function(string) --> ()` cannot be called
--@^^^ Cause: First function argument `function(<error>) --> ()` is not a subtype of `string`
--! error

--8<-- func-hint-less-arity -- feature:no_implicit_func_sig
--v function(a: function(integer, integer) --> integer)
function p(a) end

-- the hint doesn't directly affect the diagnostics
--@vv Error: The type `function(function(integer, integer) --> integer) --> ()` cannot be called
--@v-vvv Cause: First function argument `function(integer) --> integer` is not a subtype of `function(integer, integer) --> integer`
p(function(x)
    return x * 2
end)
--! error

--8<-- func-hint-more-arity -- feature:no_implicit_func_sig
--v function(a: function(integer, integer) --> integer)
function p(a) end

--@vv Error: The type `function(function(integer, integer) --> integer) --> ()` cannot be called
--@v-vvvvv Cause: First function argument `function(integer, integer, nil) --> number` is not a subtype of `function(integer, integer) --> integer`
p(function(x, y, z)
    local xy = x + y
    return xy + z --@< Error: Cannot apply + operator to `integer` and `nil`
                  --@^ Cause: `nil` is not a subtype of `number`
end)
--! error

--8<-- func-hint-varargs
--v function(a: function(integer, integer, integer...) --> integer)
function p(a) end

p(function(x, y, ...)
    return x + y
end)
--! ok

--8<-- func-hint-varargs-less-arity -- feature:no_implicit_func_sig
--v function(a: function(integer, integer, integer...) --> integer)
function p(a) end

--@v-vvv Error: The type for variadic arguments in the anonymous function is missing but couldn't be inferred from the calls
p(function(x, ...)
    return x * 2
end)
--! error

--8<-- func-hint-varargs-more-arity
--v function(a: function(integer, integer, integer...) --> integer)
function p(a) end

p(function(x, y, z, ...)
    return x + y + z
end)
--! ok

--8<-- index-rec-with-name-1
local a = { x = 3, y = 'foo' }
--# assume b: integer
b = a.x
--! ok

--8<-- index-rec-with-name-2
local a = { x = 3, y = 'foo' }
--# assume b: string
b = a.y
--! ok

--8<-- index-rec-with-wrong-name-1
local a = { x = 3, y = 'foo' }
local b = a.z + 1 -- z should be nil
--@^ Error: Cannot index `{x = 3, y = "foo"}` with `"z"`
--! error

--8<-- index-rec-with-wrong-name-2
local a = { x = 3, y = 'foo' }
local b = a.z .. 'bar' -- ditto
--@^ Error: Cannot index `{x = 3, y = "foo"}` with `"z"`
--! error

--8<-- table-update
local a = {}
a[1] = 1
a[2] = 2
a[3] = 3
--! ok

--8<-- func-number-arg-explicit
-- XXX can't propagate the number constraints upwards!
function p(a) --: number
    return a + 3
end
local x = p(4.5)
--! ok

--8<-- func-number-arg-implicit -- feature:!no_implicit_func_sig
function p(a) return a + 3 end
local x = p('what') --@< Error: The type `function(<unknown type>) --> integer` cannot be called
                    --@^ Cause: First function argument `"what"` is not a subtype of `<unknown type>`
--! error

--8<-- capture-and-return-1
local a = 42
function p() return a end
local b = p() + 54
--! ok

--8<-- capture-and-return-2
local a = 42
function p() return a end
a = p() * 54
--! ok

--8<-- func-argtype-rettype-1
function p(x) --: string --> string
    return x
end
local a = p('foo') .. 'bar'
--! ok

--8<-- func-argtype-implicit-rettype
function p(x) --: string
    return x
end
local a = p('foo') .. 'bar'
--! ok

--8<-- func-argtype-rettype-2
function p(x) --: string --> string
    return x
end
local a = p('foo') + 3 --@< Error: Cannot apply + operator to `string` and `3`
                       --@^ Cause: `string` is not a subtype of `number`
--! error

--8<-- table-update-with-integer-1
local a = {}
a[1] = 42
a[2] = 54
--! ok

--8<-- table-update-with-integer-2
local a = {} --: {}
a[1] = 42 -- now valid to do so
a[2] = 54
--! ok

--8<-- table-update-with-name
local a = {}
a.what = 42
--! ok

--8<-- table-update-with-index-and-name
local a = {}
a[1] = 42
a.what = 54
--! ok

--8<-- var-array
local a = {} --: vector<number>
--! ok

--8<-- var-array-update-with-integer-and-name
local a = {} --: vector<number>
a[1] = 42
a.what = 54
--@^ Error: Cannot index an array `vector<number>` with a non-integral index `"what"`
--! error

--8<-- var-map-update-and-index
local a = {} --: map<number, number>
a[1] = 42
a[3] = 54
a[1] = nil
local z = a[3] --: number?
--! ok

--8<-- var-map-update-and-index-subtype
local a = {} --: map<number, number>
a[1] = 42
a[3] = 54
a[1] = nil
local z = a[3] --: integer
--@^ Error: Cannot assign `number` into `integer`
--@^^ Note: The other type originates here
--! error

--8<-- var-map-update-and-index-wrong-key
local a = {} --: map<number, number>
a[1] = 42
a.string = 54 --@< Error: Cannot index `map<number, number>` with `"string"`
--! error

--8<-- var-map-update-and-index-without-nil
local a = {} --: map<number, number>
a[1] = 42
a[3] = 54
a[1] = nil
local z = a[3] --: integer
--@^ Error: Cannot assign `number` into `integer`
--@^^ Note: The other type originates here
--! error

--8<-- const-map-init
local a = {} --: const map<number, number>
--! ok

--8<-- const-map-update
local a = {} --: const map<number, number>
a[1] = 42 --@< Error: Cannot update the immutable type `const map<number, number>` by indexing
--! error

--8<-- var-any-update
local a --: any
a = {}
a = 'hello'
a = 42
--! ok

--8<-- var-any-update-and-add
local a --: any
a = 42
local b = a + 5 --@< Error: Cannot apply + operator to `any` and `5`
                --@^ Cause: `any` is not a subtype of `number`
--! error

--8<-- var-typed-error-1
local a = 3 --: number
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `number`
--@^^ Note: The other type originates here
a = 4
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `number`
--@^^ Note: The other type originates here
--! error

--8<-- var-typed-error-2
local a = 'foo' --: number
--@^ Error: Cannot assign `"foo"` into `number`
--@^^ Note: The other type originates here
a = 3
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `number`
--@^^ Note: The other type originates here
a = 4
--! error

--8<-- var-typed-error-lazy-1
local a --: number
a = 3
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `number`
--@^^ Note: The other type originates here
a = 4
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `number`
--@^^ Note: The other type originates here
--! error

--8<-- var-typed-error-lazy-2
local a --: number
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `number`
--@^^ Note: The other type originates here
a = 3
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `number`
--@^^ Note: The other type originates here
a = 4
--! error

--8<-- const-typed-error-1
local a = 3 --: const number
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `const number`
--@^^ Note: The other type originates here
a = 4
--@^ Error: Cannot assign `4` into `const number`
--@^^ Note: The other type originates here
--! error

--8<-- const-typed-error-2
local a = 'foo' --: const number
--@^ Error: Cannot assign `"foo"` into `const number`
--@^^ Note: The other type originates here
a = 3
--@^ Error: Cannot assign `3` into `const number`
--@^^ Note: The other type originates here
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `const number`
--@^^ Note: The other type originates here
--! error

--8<-- const-typed-error-lazy-1
local a --: const number
a = 3
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `const number`
--@^^ Note: The other type originates here
a = 4
--@^ Error: Cannot assign `4` into `const number`
--@^^ Note: The other type originates here
--! error

--8<-- const-typed-error-lazy-2
local a --: const number
a = 'foo'
--@^ Error: Cannot assign `"foo"` into `const number`
--@^^ Note: The other type originates here
a = 3
--@^ Error: Cannot assign `3` into `const number`
--@^^ Note: The other type originates here
a = 'bar'
--@^ Error: Cannot assign `"bar"` into `const number`
--@^^ Note: The other type originates here
--! error

--8<-- local-init-does-not-copy-modf
local x = 42 --: const integer
local y = x
y = 54
--! ok

--8<-- func-returns-rec-1
--v function() --> {a=integer}
local function p() return {a=4} end
local x = p().a + 5
--! ok

--8<-- func-returns-rec-2
--v function() --> {a=integer}
local function p() return {a=4} end
local x = p().a.b --@< Error: Tried to index a non-table type `integer`
--! error

--8<-- func-returns-rec-2-span
--v function() --> {a=integer}
local function p() return {a=4} end
local x = p().a
local y = x.b --@< Error: Tried to index a non-table type `integer`
--! error

--8<-- func-implicit-returns-rec
local function p() return {a=4} end
local x = p().a + 5
--! ok

--8<-- func-returns-seq
--v function() --> (integer, integer)
local function p()
    return 3, 4
end
--! ok

--8<-- func-returns-seq-error
--v function() --> (integer, string)
local function p()
    return 3, 4
    --@^ Error: Attempted to return a type `(3, 4)` which is incompatible to given return type `(integer, string)`
    --@^^ Cause: Second return type `4` is not a subtype of `string`
end
--! error

--8<-- func-returns-seq-with-nil
--v function() --> (integer, nil)
local function p()
    return 3
end
--! ok

--8<-- func-returns-with-nil
--v function() --> integer
local function p()
    return 3, nil
end
--! ok

--8<-- func-returns-seq-union
--v function(n: boolean) --> (string, string)
local function p(n)
    if n then return 'string' else return nil, 'error' end
end
--! ok

--8<-- func-returns-wrong
--v function()
local function f()
    return 'foo'
    --@^ Error: Attempted to return a type `("foo")` which is incompatible to given return type `()`
    --@^^ Cause: First return type `"foo"` is not a subtype of `nil`
end
--! error

--8<-- assign-func-no-hint-1
local x --: function(string)
x = function(a) end
--! ok

--8<-- assign-func-no-hint-2 -- feature:no_implicit_func_sig
local x
x = function(a) end --@< Error: The type for this argument in the anonymous function is missing but couldn't be inferred from the calls
--! error

--8<-- assign-from-seq-1
local function p()
    return 3, 4, 5
end
local a, b = p() --: integer, integer
--! ok

--8<-- assign-from-seq-2
local function p()
    return 3, 4, 'string'
end
local a, b = p() --: integer, integer
--! ok

--8<-- assign-from-seq-3
local function p()
    return 3, 'string', 5
end
local a, b = p() --: integer, integer
--@^ Error: Cannot assign `"string"` into `integer`
--@^^ Note: The other type originates here
--! error

--8<-- assign-from-seq-with-nil-1
local function p()
    return 3, 4
end
local a, b, c = p() --: integer, integer, nil
--! ok

--8<-- assign-from-seq-with-nil-2
local function p()
    return 3, 4, nil
end
local a, b = p() --: integer, integer
--! ok

--8<-- assign-from-seq-union-1
local function p(n) --: boolean
    if n then return 'string' else return nil, 'error' end
end
local a, b = p(false) --: string, string
local a, b = p(true) --: string, string
--! ok

--8<-- assign-from-seq-union-2
local function p(n) --: boolean
    if n then return 'string' else return nil, 'error' end
end
local a, b = p(false) --: number, number
--@^ Error: Cannot assign `"string"` into `number`
--@^^ Note: The other type originates here
--@^^^ Error: Cannot assign `"error"?` into `number`
--@^^^^ Note: The other type originates here
--! error

--8<-- table-from-seq
local function p()
    return 1, 2, 3
end
local a = {p(), p()} --: {integer, integer, integer, integer}
local b = {foo = p()} --: {foo = integer}
local c = {p(), bar = p()} --: map<integer|string, integer>
--! ok

--8<-- funccall-from-seq
local function p()
    return 1, 'string', false
end
--v function(a: number, b: integer, c: number, d: integer, e: string, f: boolean)
local function q(a,b,c,d,e,f) end
q(3.14, p(), -42, p())
--! ok

--8<-- func-varargs-type-1
--v function(...: integer)
local function p(...) end
p(1, 2, 3)
--! ok

--8<-- func-varargs-type-2
--v function(...: integer)
local function p(...) end
p(1, false, 3) --@< Error: The type `function(integer...) --> ()` cannot be called
               --@^ Cause: Second function argument `false` is not a subtype of `integer`
--! error

--8<-- func-varargs-type-with-nil
--v function(...: integer)
local function p(...) end
p(1, 2, 3, nil, nil, nil)
--! ok

--8<-- func-varargs-type-delegated -- feature:!no_implicit_func_sig
--v function(...: string)
function f(...)
end
function g(...)
    f(...)
end
--! ok

--8<-- type
--# type known_type = number
--# assume p: known_type
local q = p - 5
--! ok

--8<-- type-local
do
    --# type known_type = number
end
--# assume p: known_type --@< Error: Type `known_type` is not defined
--! error

--8<-- type-no-shadowing
--# type known_type = integer --@< Note: The type was originally defined here
do
    --# type known_type = number --@< Error: A type named `known_type` is already defined
end
--! error

--8<-- type-no-recursive
--# type known_type = known_type --@< Error: Type `known_type` is not defined
--! error

--8<-- type-transitive
--# type some_type = integer
--# type another_type = some_type
--# assume p: another_type
local q = p * 3
--! ok

--8<-- type-unknown-type
--# type some_type = another_type --@< Error: Type `another_type` is not defined
--! error

--8<-- type-transitive-out-of-order
--# type some_type = another_type --@< Error: Type `another_type` is not defined
--# type another_type = integer -- this is intentional
--! error

--8<-- invalid-open
--# open lua40 --@< Error: Cannot find the built-in library name given to `--# open` directive
--! error

--8<-- duplicate-open
--# open lua51
--# open lua51
print('hello')
--! ok

--8<-- lua51-no-implicit
print('hello') --@< Error: Global or local variable `print` is not defined
--! error

--8<-- lua51-print
--# open lua51
print('hello')
--! ok

--8<-- assert-truthy
--# open lua51
--# assume p: integer?
assert(p)
print(p + 5)
--! ok

--8<-- assert-disjunctive
--# open lua51
--# assume p: integer?
--# assume q: integer?
assert(p or q)
print(p + 5) --@< Error: Cannot apply + operator to `integer?` and `5`
             --@^ Cause: `integer?` is not a subtype of `number`
--! error

--8<-- assert-conjunctive
--# open lua51
--# assume p: integer?
--# assume q: integer?
assert(p and q)
print(p + q)
--! ok

--8<-- assert-conjunctive-partial-1
--# open lua51
--# assume p: integer?
--# assume q: integer?
assert(p and not q)
print(p + 5)
--! ok

--8<-- assert-conjunctive-partial-2
--# open lua51
--# assume p: integer?
--# assume q: integer?
assert(p and not q)
print(q + 5) --@< Error: Cannot apply + operator to `nil` and `5`
             --@^ Cause: `nil` is not a subtype of `number`
--! error

--8<-- assert-conjunctive-partial-dynamic
--# open lua51
--# assume p: WHATEVER
--# assume q: WHATEVER
assert(p and not q)
print(p + 5)
print(q + 5) -- should not alter dynamic types
--! ok

--8<-- assert-number-type-1
--# open lua51
--# assume p: integer|string
assert(type(p) == 'number')
print(p + 5)
--! ok

--8<-- assert-number-type-2
--# open lua51
--# assume p: integer|string
assert('number' == type(p))
print(p + 5)
--! ok

--8<-- assert-integer-type
--# open lua51
--# assume p: integer|string
assert(type(p) == 'integer') -- no such type in Lua 5.1
--@^ Error: The literal cannot appear as a return type name for `type`
--! error

--8<-- assert-same-type
--# open lua51
assert(type(13) == type('string')) -- no-op
--! ok

--8<-- assert-not-1
--# open lua51
--# assume assert_not: const [assert_not] function(any)
--# assume p: integer?
--# assume q: integer?
assert_not(p or not q) -- i.e. assert(not p and q)
print(q + 5)
--! ok

--8<-- assert-not-2
--# open lua51
--# assume assert_not: const [assert_not] function(any)
--# assume p: integer?
--# assume q: integer?
assert_not(p or not q) -- i.e. assert(not p and q)
print(p + 5) --@< Error: Cannot apply + operator to `nil` and `5`
             --@^ Cause: `nil` is not a subtype of `number`
--! error

--8<-- assert-type
--# open lua51
--# assume assert_type: const [assert_type] function(any, string)
--# assume p: integer|string
assert_type(p, 'integer')
print(p + 5)
--! ok

--8<-- assign-identical
--# assume x: WHATEVER
x = x
--! ok

--8<-- call-identical
--# assume x: WHATEVER
x(x)
--! ok

--8<-- index-identical
--# assume x: WHATEVER
x[x]()
--! ok

--8<-- if-assign-identical
--# assume x: WHATEVER
if x then x = 42 end
--! ok

--8<-- while-assign-identical
--# assume x: WHATEVER
while x do x = 42 end
--! ok

--8<-- for-assign-identical
--# assume x: WHATEVER
for i = 1, x do x = 42 end
--! ok

--8<-- for-identical
--# assume x: WHATEVER
for i = x, x do end
--! ok

--8<-- table-identical
--# assume x: 'hello'
local p = {[x] = x}
--! ok

--8<-- assign-table-to-table
--# assume x: table
--# assume y: table
x = y
--! ok

--8<-- assign-function-to-function
--# assume x: function
--# assume y: function
x = y
--! ok

--8<-- assign-var-subtype-1
--# assume p: number
--# assume q: integer
p = q
--! ok

--8<-- assign-var-subtype-2
--# assume p: integer
--# assume q: 1|2
p = q
--! ok

--8<-- assign-var-suptype-1
--# assume p: integer
--# assume q: number
p = q
--@^ Error: Cannot assign `number` into `integer`
--@^^ Note: The other type originates here
--! error

--8<-- assign-var-suptype-2
--# assume p: 1|2
--# assume q: integer
p = q
--@^ Error: Cannot assign `integer` into `(1|2)`
--@^^ Note: The other type originates here
--! error

--8<-- assign-var-map-eqtype
--# assume p: map<string, number>
--# assume q: map<string, number?>
--# assume r: map<string, number!>
--# assume x: number
p.x = x
q.x = x
r.x = x
--! ok

--8<-- assign-var-map-subtype
--# assume p: map<string, number>
--# assume q: map<string, number?>
--# assume r: map<string, number!>
--# assume x: integer
p.x = x
q.x = x
r.x = x
--! ok

--8<-- assign-var-map-nil
--# assume p: map<string, number>
--# assume q: map<string, number?>
--# assume r: map<string, number!>
p.x = nil
q.x = nil
r.x = nil
--! ok

--8<-- assign-var-map-suptype-1
--# assume p: map<string, integer>
--# assume q: number
p.x = q
--@^ Error: Cannot assign `number` into `integer`
--@^^ Note: The other type originates here
--! error

--8<-- assign-var-map-suptype-2
--# assume p: map<string, integer?>
--# assume q: number
p.x = q
--@^ Error: Cannot assign `number` into `integer?`
--@^^ Note: The other type originates here
--! error

--8<-- assign-var-map-suptype-3
--# assume p: map<string, integer!>
--# assume q: number
p.x = q
--@^ Error: Cannot assign `number` into `integer`
--@^^ Note: The other type originates here
-- the error message should not mention `integer!`
--! error

--8<-- assign-record-1
local t = {}
t.a = 42
local x = t.b --@< Error: Cannot index `{a = integer}` with `"b"`
--! error

--8<-- assign-record-2
local t = {} --: {a = integer}
local x = t.a
t.a = 42
local x = t.a --: integer
--! ok

--8<-- assign-record-extension
local t = {}
local u = {} --: {}
t.a = 42
u.b = 54
local x = t.a + u.b --: integer
--! ok

--8<-- assign-record-row-variable
local x = {a = 1, b = 'foo'}

local y = x --: {a = integer, b = string, c = string}
y.c = 'foo'
local c = x.c --: string

local z = x --: {a = integer, b = string, c = integer}
--@^ Error: Cannot assign `{a = 1, b = "foo", c = string}` into `{a = integer, b = string, c = integer}`
--@^^ Note: The other type originates here
--! error

--8<-- require-dummy
--# open lua51
x = require(y) --@< Error: Global or local variable `y` is not defined
--! error

--8<-- require-unknown
--# open lua51
x = require 'a' --@< Warning: Cannot resolve the module name given to `require`
--! ok

--8<-- require-unknown-returns-1
--# open lua51
x = require 'a' --@< Warning: Cannot resolve the module name given to `require`
print(x + 4) --@< Error: Cannot apply + operator to `any` and `4`
             --@^ Cause: `any` is not a subtype of `number`
--! error

--8<-- require-unknown-returns-2
--# open lua51
--# assume x: integer
x = require 'A' --@< Warning: Cannot resolve the module name given to `require`
                --@^ Error: Cannot assign `any` into `integer`
                --@^^ Note: The other type originates here

--& a
return 42

--! error

--8<-- require-returns-integer
--# open lua51
--# assume x: integer
x = require 'a'

--& a
return 42

--! ok

--8<-- require-returns-false
--# open lua51
require 'a'
--@^ Error: Returning `false` from the module disables Lua's protection against recursive `require` calls and is heavily discouraged
-- XXX the span should be ideally at `return`

--& a
return false -- false triggers a Lua bug, so it is prohibited

--! error

--8<-- require-returns-dynamic
--# open lua51
local a = require 'a'
a(a*a[a])

--& a
--# assume x: WHATEVER
return x

--! ok

--8<-- require-returns-string
--# open lua51
--# assume x: string
x = require 'a'

--& a
local function p() return 'hello' end
return p()

--! ok

--8<-- require-returns-func
--# open lua51
print((require 'a')() + 5)

--& a
local function p() return 42 end
return p

--! ok

--8<-- require-returns-not-fully-resolved
--# open lua51
require 'a'
--@^ Error: The module has returned a type `<unknown type>` that is not yet fully resolved
-- XXX the span should be ideally at `return`

--& a
--# open `internal kailua_test`
return kailua_test.gen_tvar()

--! error

--8<-- require-nested
--# open lua51
require 'a'

--& a
require 'b'

--& b
return true

--! ok

--8<-- require-nested-idempotent
--# open lua51
require 'a'
require 'b'
require 'a'

--& a
require 'b'

--& b
return true

--! ok

--8<-- require-recursive
--# open lua51
require 'a' --@< Note: The module was previously `require`d here

--& a
require 'b'

--& b
require 'a' --@< Error: Recursive `require` was requested

--! error

--8<-- require-disconnected
--# open lua51

--& a
require 'b'

--& b
require 'a'

-- check is dynamic
--! ok

--8<-- require-name-expr
--# open lua51
--# assume x: number
x = require('a' .. 'b')

--& ab
return 42

--! ok

--8<-- index-assign-typed
local p = {x = 5, y = 6} --: {x=number, y=number}
p.x = 'string' --@< Error: Cannot assign `"string"` into `number`
               --@^ Note: The other type originates here
--! error

--8<-- index-assign-dynamic
--# assume p: WHATEVER
p[1] = 42
--! ok

--8<-- for-in-simple-iter-1
--# assume func: const function() --> number?
for x in func do
    local a = x * 3
end
--! ok

--8<-- for-in-simple-iter-2
--# assume func: const function() --> number    -- technically infinite loop
for x in func do
    local a = x * 3
end
--! ok

--8<-- for-in-simple-iter-3
--# assume func: const function() --> number|string
for x in func do
    local a = x * 3 --@< Error: Cannot apply * operator to `(number|string)` and `3`
                    --@^ Cause: `(number|string)` is not a subtype of `number`
end
--! error

--8<-- for-in-stateful-iter-1
--# assume func: const function({const integer}, integer?) --> integer?
--# assume state: const {const integer}
--# assume first: const integer?
for x in func, state, first do
    local a = x * 3
end
--! ok

--8<-- for-in-stateful-iter-2
--# assume func: const function({const integer}, integer|string?) --> integer?
--# assume state: const {const integer}
--# assume first: const integer|string     -- the first value is silently discard
for x in func, state, first do
    local a = x * 3
end
--! ok

--8<-- for-in-multi
--# assume func: const function({const integer}, integer|string?) --> (integer?, string)
--# assume state: const {const integer}
--# assume first: const integer?
for x, y in func, state, first do
    local a = x --: integer
    local b = y --: string
end
--! ok

--8<-- for-in-non-func
--@v Error: The iterator given to `for`-`in` statement returned a non-function type `"hello"`
for x in 'hello' do
end
--! error

--8<-- for-in-non-func-recover
--@v Error: The iterator given to `for`-`in` statement returned a non-function type `"hello"`
for x in 'hello' do
    x()
    y() --@< Error: Global or local variable `y` is not defined
end
--! error

--8<-- lua51-ipairs-integer-array
--# open lua51
--# assume p: vector<integer>
for x, y in ipairs(p) do
    local a = x * 3
    local b = y * 4
end
--! ok

--8<-- lua51-ipairs-string-array-1
--# open lua51
--# assume p: vector<string>
for x, y in ipairs(p) do
    local a = x * 3
    local b = y .. 'a'
end
--! ok

--8<-- lua51-ipairs-string-array-2
--# open lua51
--# assume p: vector<string>
for x, y in ipairs(p) do
    local b = y * 4 --@< Error: Cannot apply * operator to `string` and `4`
                    --@^ Cause: `string` is not a subtype of `number`
end
--! error

--8<-- lua51-ipairs-no-map
--# open lua51
--# assume p: map<integer, string>
for x, y in ipairs(p) do
    --@^ Error: The type `[generic_pairs] function(vector<const WHATEVER>) --> (function(vector<const WHATEVER>, integer) --> (integer?, any), vector<const WHATEVER>, integer)` cannot be called
    --@^^ Cause: First function argument `map<integer, string>` is not a subtype of `vector<const WHATEVER>`
    -- XXX WHATEVER is temporary
end
--! error

--8<-- lua51-ipairs-no-table
--# open lua51
--# assume p: table
for x, y in ipairs(p) do
    --@^ Error: The type `[generic_pairs] function(vector<const WHATEVER>) --> (function(vector<const WHATEVER>, integer) --> (integer?, any), vector<const WHATEVER>, integer)` cannot be called
    --@^^ Cause: First function argument `table` is not a subtype of `vector<const WHATEVER>`
    -- XXX WHATEVER is temporary
end
--! error

--8<-- lua51-ipairs-no-non-table
--# open lua51
--# assume p: string
for x, y in ipairs(p) do
    --@^ Error: The type `[generic_pairs] function(vector<const WHATEVER>) --> (function(vector<const WHATEVER>, integer) --> (integer?, any), vector<const WHATEVER>, integer)` cannot be called
    --@^^ Cause: First function argument `string` is not a subtype of `vector<const WHATEVER>`
    -- XXX WHATEVER is temporary
end
--! error

--8<-- lua51-pairs-integer-array
--# open lua51
--# assume p: vector<integer>
for x, y in pairs(p) do
    local a = x * 3
    local b = y * 4
end
--! ok

--8<-- lua51-pairs-string-array-1
--# open lua51
--# assume p: vector<string>
for x, y in pairs(p) do
    local a = x * 3
    local b = y .. 'a'
end
--! ok

--8<-- lua51-pairs-string-array-2
--# open lua51
--# assume p: vector<string>
for x, y in pairs(p) do
    local b = y * 4 --@< Error: Cannot apply * operator to `string` and `4`
                    --@^ Cause: `string` is not a subtype of `number`
end
--! error

--8<-- lua51-pairs-integer-integer-map
--# open lua51
--# assume p: map<integer, integer>
for x, y in pairs(p) do
    local a = x * 3
    local b = y * 4
end
--! ok

--8<-- lua51-pairs-integer-string-map-1
--# open lua51
--# assume p: map<integer, string>
for x, y in pairs(p) do
    local a = x * 3
    local b = y .. 'a'
end
--! ok

--8<-- lua51-pairs-integer-string-map-2
--# open lua51
--# assume p: map<integer, string>
for x, y in pairs(p) do
    local b = y * 4 --@< Error: Cannot apply * operator to `string` and `4`
                    --@^ Cause: `string` is not a subtype of `number`
end
--! error

--8<-- lua51-pairs-string-integer-map-1
--# open lua51
--# assume p: map<string, integer>
for x, y in pairs(p) do
    local a = x .. 'a'
    local b = y * 4
end
--! ok

--8<-- lua51-pairs-string-integer-map-2
--# open lua51
--# assume p: map<string, integer>
for x, y in pairs(p) do
    local a = x * 3 --@< Error: Cannot apply * operator to `string` and `3`
                    --@^ Cause: `string` is not a subtype of `number`
end
--! error

--8<-- lua51-pairs-table
--# open lua51
--# assume p: table
for x, y in pairs(p) do
end
--! ok

--8<-- lua51-pairs-table-any
--# open lua51
--# assume p: table
for x, y in pairs(p) do
    print(p .. 3) --@< Error: Cannot apply .. operator to `table` and `3`
                  --@^ Cause: `table` is not a subtype of `(number|string)`
end
--! error

--8<-- lua51-pairs-no-non-table
--# open lua51
--# assume p: string
for x, y in pairs(p) do
    --@^ Error: The type `[generic_pairs] function(table) --> (function(table, any) --> (any?, any), table, any)` cannot be called
    --@^^ Cause: First function argument `string` is not a subtype of `table`
end
--! error

--8<-- lua51-update-package-cpath
--# open lua51
package.cpath = '?.lua'
--! ok

--8<-- redefine-global
p = 42 --: integer
p = 54 --: integer --@< Error: Cannot redefine the type of a variable `p`
p = 63 --: integer --@< Error: Cannot redefine the type of a variable `p`
--! error

--8<-- redefine-global-in-single-stmt-1
p, p = 42, 54 --: integer, integer
--@^ Error: Cannot redefine the type of a variable `p`
--! error

--8<-- redefine-global-in-single-stmt-2
p, p, p = 42, 54, 63 --: integer, integer, integer
--@^ Error: Cannot redefine the type of a variable `p`
--@^^ Error: Cannot redefine the type of a variable `p`
--! error

--8<-- redefine-global-func
function p() end
function p() end --@< Error: Cannot redefine the type of a variable `p`
--! error

--8<-- redefine-local
local p = 42 --: integer
local p = 54 --: integer
local p = 'string' --: string
--! ok

--8<-- redefine-local-func
local function p() end
local function p() end
--! ok

--8<-- unknown-attr
--# --@v Warning: `sudo` is an unknown type attribute and ignored
--# assume sudo: [sudo] {
--#     --@v Warning: `make_sandwich` is an unknown type attribute and ignored
--#     make_sandwich = const [make_sandwich] function(boolean)
--# }
--! ok

--8<-- builtin-with-subtyping-1
--# assume x: [`internal subtype`] number
--# assume y: number
x = y
--@^ Error: Cannot assign `number` into `[internal subtype] number`
--@^^ Note: The other type originates here
--! error

--8<-- builtin-with-subtyping-2
--# assume x: [`internal subtype`] number
--# assume y: number
y = x
--! ok

--8<-- builtin-without-subtyping-1
--# assume x: [`internal no_subtype`] number
--# assume y: number
x = y
--! ok

--8<-- builtin-without-subtyping
--# assume x: [`internal no_subtype`] number
--# assume y: number
y = x
--! ok

--8<-- lua51-package-path-literal
--# open lua51
package.path = '?.lua'
package.cpath = '?.so'
--! ok

--8<-- lua51-package-path-non-literal
--# open lua51
--# assume x: string
package.path = x
--@^ Warning: Cannot infer the values assigned to the `package_path` built-in variable; subsequent `require` may be unable to find the module path
package.cpath = x
--@^ Warning: Cannot infer the values assigned to the `package_cpath` built-in variable; subsequent `require` may be unable to find the module path
--! ok

--8<-- package-path-non-literal-local-1
-- while this is very contrived, this and subsequent tests check the ability to
-- declare *and* assign special variables altogether.
--# assume x: string
local p = x --: [package_path] string
--@^ Warning: Cannot infer the values assigned to the `package_path` built-in variable; subsequent `require` may be unable to find the module path
--! ok

--8<-- package-path-non-literal-local-2
--# assume x: string
local p = '' --: [package_path] string
local q = 0 --: integer
p, q = x, 42
--@^ Warning: Cannot infer the values assigned to the `package_path` built-in variable; subsequent `require` may be unable to find the module path
--! ok

--8<-- package-path-non-literal-global-1
--# assume x: string
p = x --: [package_path] string
--@^ Warning: Cannot infer the values assigned to the `package_path` built-in variable; subsequent `require` may be unable to find the module path
--! ok

--8<-- package-path-non-literal-global-2
--# assume x: string
p, q = x, x --: [package_path] string, [package_cpath] string
--@^ Warning: Cannot infer the values assigned to the `package_path` built-in variable; subsequent `require` may be unable to find the module path
--@^^ Warning: Cannot infer the values assigned to the `package_cpath` built-in variable; subsequent `require` may be unable to find the module path
--! ok

--8<-- if-false-warning-1 -- feature:warn_on_useless_conds
--@v-vvvvv Warning: These `if` case(s) are never executed
if false then --@< Note: This condition always evaluates to a falsy value
    local a
    local b
    local c
end
--! ok

--8<-- if-false-warning-2 -- feature:warn_on_useless_conds
--@v-vv Warning: These `if` case(s) are never executed
if false then --@< Note: This condition always evaluates to a falsy value
    local a
else
    local b
    local c
end
--! ok

--8<-- if-false-warning-3 -- feature:warn_on_useless_conds
--# assume x: boolean
if x then
    local a
--@v-vv Warning: These `if` case(s) are never executed
elseif false then --@< Note: This condition always evaluates to a falsy value
    local b
--@v-vv Warning: These `if` case(s) are never executed
elseif false then --@< Note: This condition always evaluates to a falsy value
    local c
else
    local d
end
--! ok

--8<-- if-true-warning-1 -- feature:warn_on_useless_conds
if true then --@< Warning: This condition always evaluates to a truthy value
    local a
    local b
    local c
end
--! ok

--8<-- if-true-warning-2 -- feature:warn_on_useless_conds
--# assume x: boolean
if x then
    local a
elseif true then --@< Warning: This condition always evaluates to a truthy value
    local b
end
--! ok

--8<-- if-true-warning-3 -- feature:warn_on_useless_conds
--# assume x: boolean
if true then --@< Note: This condition always evaluates to a truthy value
    local a
elseif x then --@<-vvvv Warning: These `if` case(s) are never executed
    local b
else
    local c
end
--! ok

--8<-- if-true-warning-4 -- feature:warn_on_useless_conds
--# assume x: boolean
if x then
    local a
elseif true then --@< Note: This condition always evaluates to a truthy value
    local b
elseif true then --@<-vvvvvv Warning: These `if` case(s) are never executed
    local c
elseif false then
    local d
else
    local e
end
--! ok

--8<-- if-warning-varargs-1 -- feature:warn_on_useless_conds exact
--v function() --> (string...)
function f() end
if f() then
end
--! ok

--8<-- if-warning-varargs-2 -- feature:warn_on_useless_conds
--v function() --> (string, string...)
function f() end
if f() then --@< Warning: This condition always evaluates to a truthy value
end
--! ok

--8<-- unassigned-local-var-1
local p --: string!
--! ok

--8<-- unassigned-local-var-2
local p --: string!
--v function(x: string)
local function f(x) end
f(p)
--@^ Error: The variable is not yet initialized
--@1 Note: The variable was not implicitly initialized to `nil` as its type is `string!`
f(p)
--@^ Error: The variable is not yet initialized
--@1 Note: The variable was not implicitly initialized to `nil` as its type is `string!`
p = 'string'
f(p) -- no longer an error
--! error

--8<-- unassigned-local-var-nil-1
local p --: string
--! ok

--8<-- unassigned-local-var-nil-2
local p --: string
--v function(x: string)
local function f(x) end
f(p)
p = 'string'
f(p)
p = nil
f(p)
--! ok

--8<-- unassigned-global-var
q, p = 42 --: integer, string!
--@^ Error: Cannot assign `nil` into `string!`
--@^^ Note: The other type originates here
--! error

--8<-- table-update-nested-1
local a = {}
a.b = {}
a.b.c = {}
a.b.c.d = {}
--! ok

--8<-- table-update-nested-2
local a = { b = {} }
a.b.c = {}
a.b.c.d = {}
--! ok

--8<-- table-update-nested-3
local a = { b = { c = {} } }
a.b.c.d = {}
--! ok

--8<-- method-decl
local p = {}
function p.a() end
p.a()
--! ok

--8<-- method-decl-nested
local p = {a = {}}
function p.a.b() end
p.a.b()
--! ok

--8<-- method-decl-self
local p = {}
function p:a() end
p:a()
--! ok

--8<-- method-decl-self-nested
local p = {a = {}}
function p.a:b() end
p.a:b()
--! ok

--8<-- method-decl-nontable
local p = 42
function p.a() end --@< Error: Tried to index a non-table type `integer`
p.a()              --@< Error: Tried to index a non-table type `integer`
--! error

--8<-- method-decl-nontable-nested
local p = {a = 42}
function p.a.b() end --@< Error: Tried to index a non-table type `42`
p.a.b()              --@< Error: Tried to index a non-table type `42`
--! error

--8<-- method-decl-const
local p = {} --: const {}
function p.a() end --@< Error: Cannot update the immutable type `const {}` by indexing
p.a() --@< Error: Cannot index `const {}` with `"a"`
--! error

--8<-- method-decl-const-nested
local p = { a = {} } --: const {a = const {}}
function p.a.b() end --@< Error: Cannot update the immutable type `const {}` by indexing
p.a.b() --@< Error: Cannot index `const {}` with `"b"`
--! error

--8<-- methodcall-string-meta-table
--# assume blah: [string_meta] { byte = function(string) --> integer }
local x = ('f'):byte() --: integer
--! ok

--8<-- methodcall-string-meta-dynamic
--# assume blah: [string_meta] WHATEVER
local x = ('f'):foobar(1, 'what', false) --: string
--! ok

--8<-- methodcall-string-meta-undefined
local x = ('f'):byte()
--@^ Error: Cannot use string methods as a metatable for `string` type is not yet defined
--! error

--8<-- methodcall-string-meta-non-table
--# assume blah: [string_meta] integer
--@^ Note: A metatable for `string` type has been previously defined here
local x = ('f'):byte() --: integer
--@^ Error: A metatable for `string` type has been defined but is not a table
-- XXX it is not very clear that we should catch it from the definition
--! error

--8<-- string-meta-redefine
--# assume blah: [string_meta] { byte = function(string) --> integer }
--@^ Note: A metatable for `string` type has been previously defined here
--# assume blah2: [string_meta] { lower = function(string) --> string }
--@^ Error: A metatable for `string` type cannot be defined more than once and in general should only be set via `--# open` directive
--! error

--8<-- lua51-string-meta
--# open lua51
local x = ('f'):byte() --: integer
local x, y, z = ('XY'):byte() --: integer, integer, integer
local x, y, z = ('XY'):byte(10, 15) --: integer, integer, integer
local x = ('foo'):find('o') --: integer
local x = ('%s%s'):format('x', 'y') --: string
local x = ('xyzzy'):len() --: integer
local x = ('xyZzy'):lower() --: string
local x = ('xyZzy'):upper() --: string
local x = ('*'):rep(80) --: string
local x = ('abracadabra'):reverse() --: string
local x = ('notice'):sub(4) --: string
local x = ('notice'):sub(1, 3) --: string
local x = ('notice'):sub(10, 10) --: string
--! ok

-->8-- lua51-assert-string-type-and-meta
--# open lua51
local function f(s)
    assert(type(s) == 'string')
    return s:lower()
end

f('string')
-- in theory f(42) and others may work, since assertion is a runtime type check
-- and the compile time type checker may remain sound without any further check.
-- in practice the current constraint solver is a bit quirky and will reject them.
-- both are not what we want in the long term, clearly. TODO

--! ok

--8<-- methodcall-recover
local q = {}
local x = q:f() --@< Error: Cannot index `{}` with `"f"`
-- `x` should be a dummy type now, so the following shouldn't fail
x()
local p = 3 + x
--! error

-->8-- lua51-lt-operand-inferred-from-funcarg
--# open lua51
local function negative(x)
    assert(type(x) == 'number') -- won't destroy the type varible
    return x < 0
end
--! ok

--8<-- no-check
--v [no_check]
--v function(x: integer) --> integer
function foo(x)
    return x + "string"
end
--! ok

--8<-- no-check-func-type
--v [no_check]
--v function(x: integer) --> integer
function foo(x)
    return x + "string"
end

local a = foo(3) --: integer

local b = foo(4) --: string
--@^ Error: Cannot assign `integer` into `string`
--@^^ Note: The other type originates here

local c = foo('hi') --: integer
--@^ Error: The type `function(integer) --> integer` cannot be called
--@^^ Cause: First function argument `"hi"` is not a subtype of `integer`

--! error

--8<-- no-check-method-type-1
foo = {}

--v [no_check]
--v function(self: table, x: integer) --> integer
function foo:bar(x)
    return x + "string"
end

local a = foo:bar(3) --: integer
--! ok

--8<-- no-check-method-type-2
foo = {}

--v [no_check]
--v function(self: integer, x: integer) --> integer
function foo:bar(x)
    return x + "string"
end

-- this is an error because `self` type is not affected by [no_check]
--@vv Error: The type `function(integer, integer) --> integer` cannot be called
--@v Cause: First function argument `{bar = function(integer, integer) --> integer}` is not a subtype of `integer`
local a = foo:bar(3) --: integer

--! error

--8<-- no-check-untyped-args -- feature:!no_implicit_func_sig
--v [no_check]
function foo(x) --> boolean --@< Error: [no_check] attribute requires the arguments to be typed
    return x + "string"
end
--! error

--8<-- no-check-untyped-varargs
--@v-vvvvv Error: [no_check] attribute requires the variadic arguments to be typed
--v [no_check]
function foo(x, --: integer
             ...) --> boolean
    return x + "string"
end
--! error

--8<-- no-check-untyped-returns
--@v-vvvv Error: [no_check] attribute requires the return type to be present
--v [no_check]
function foo(x) --: integer
    return x + "string"
end
--! error

--8<-- no-check-untyped-self
foo = {}
--v [no_check]
--v function(self, x: integer) --> boolean --@< Error: [no_check] attribute requires the `self` argument to be typed
function foo:bar(x)
    return x + "string"
end
--! error

--8<-- lua51-string-add-method
--# open lua51
--v function(self: string) --> string
function string:trim()
    return self:gsub('^%s+', ''):gsub('%s+$', '')
end
--! ok

--8<-- local-func-without-sibling-scope-1
local r
--v function(p: any)
function r(p)
end
--! ok

--8<-- local-func-without-sibling-scope-2
local r
do
    local s
    --v function(p: any)
    function r(p)
    end
end
--! ok

--8<-- void-arbitrary
x = 42
y = "foo"
-- the first is a parsing error, and the second is a type error from the recovered AST
x + y --@< Error: Only function calls are allowed as statement-level expressions
      --@^ Error: Cannot apply + operator to `42` and `"foo"`
      --@^^ Cause: `"foo"` is not a subtype of `number`
--! error

--8<-- assign-empty-rhs
a = 42 --: integer
b = "string" --: string
do
    a, b -- this won't generate any type error! the following is a parsing error.
end --@< Error: Expected `=`, got a keyword `end`
--! ok

--8<-- funccall-desugared
local function f(x) --: any
end
f'oo'
f[[unction]]
f{reak=true}
--! ok

--8<-- seq-type-without-paren
local function f()
    return 1, 2, 3
end
--v function(a: integer, b: integer)
local function g(a, b)
end
g(0, f()) --@< Error: The type `function(integer, integer) --> ()` cannot be called
          --@^ Cause: Third function argument `2` is not a subtype of `nil`
--! error

--8<-- seq-type-with-paren
local function f()
    return 1, 2, 3
end
--v function(a: integer, b: integer)
local function g(a, b)
end
g(0, (f()))
--! ok

--8<-- table-lit-duplicate-key-1
local a = {
    what = 4,
    what = 5, --@< Error: The key `what` is duplicated in the table constructor
              --@^^ Note: The key was previously assigned here
}
--! error

--8<-- table-lit-duplicate-key-2
local a = {
    1,
    2,
    3,
    4,
    [2] = 5, --@< Error: The key `2` is duplicated in the table constructor
             --@^^^^ Note: The key was previously assigned here
}
--! error

--8<-- table-lit-duplicate-key-3
local a = {
    [2] = 0,
    1,
    2, --@< Error: The key `2` is duplicated in the table constructor
       --@^^^ Note: The key was previously assigned here
    3,
    4,
}
--! error

--8<-- table-lit-arbitrary-key
--# assume k: string
local a = {[k] = 42} --@< Error: The key type `string` is not known enough, not a string or integer, or not known ahead of time as the table constructor should always be a record
--! error

--8<-- table-lit-non-stringy-key
--# assume k: table
local a = {[k] = 42} --@< Error: The key type `table` is not known enough, not a string or integer, or not known ahead of time as the table constructor should always be a record
--! error

--8<-- table-lit-bounded-seq
function f() return 3, 4 end
local a = {1, 2, f()} --: {integer, integer, integer, integer}
--! ok

--8<-- table-lit-unbounded-seq
--v [no_check]
--v function() --> (integer...)
function f() end
local a = {1, 2, f()} --@< Error: This expression has an unknown number of return values, so cannot be used as the last value in the table constructor which should always be a record
--! error

--8<-- table-lit-subtyping-1
local a = {1, 2, 3} --: vector<integer>
local b = {1, 2, 3, [4] = 4} --: vector<integer>
local c = {1, 2, 3, [8] = 4} --: map<integer, integer>
--! ok

--8<-- table-lit-subtyping-2
local d = {a = 3, b = 4} --: map<string, integer>
local e = {1, 2, 3, string = 4} --: map<integer|string, integer>
--! ok

--8<-- table-lit-subtyping-3
local x = {1, 2, 3, [5] = 4} --: vector<integer>
--@^ Error: Cannot assign `{1, 2, 3, 5 = 4}` into `vector<integer>`
--@^^ Note: The other type originates here
--! error

--8<-- table-lit-subtyping-4
local y = {1, 2, 3, string = 4} --: vector<integer>
--@^ Error: Cannot assign `{1, 2, 3, string = 4}` into `vector<integer>`
--@^^ Note: The other type originates here
--! error

--8<-- table-lit-subtyping-5
local z = {1, 2, 3, string = 4} --: map<integer, integer>
--@^ Error: Cannot assign `{1, 2, 3, string = 4}` into `map<integer, integer>`
--@^^ Note: The other type originates here
--! error

--8<-- no-table-union
local a --: {string} | {integer}
--@^ Error: This union type is not supported in the specification
--@^^ Cause: Cannot create a union type of `{string}` and `{integer}`
--@^^^ Note: The other type originates here
--! error

--8<-- no-function-union
local a --: (function(string)) | (function(integer))
--@^ Error: This union type is not supported in the specification
--@^^ Cause: Cannot create a union type of `function(string) --> ()` and `function(integer) --> ()`
--@^^^ Note: The other type originates here
--! error

--8<-- no-true-false-union
local a --: true | false -- should be written as `boolean`
--@^ Error: This union type is not supported in the specification
--@^^ Cause: Cannot create a union type of `true` and `false`
--@^^^ Note: The other type originates here
--! error

--8<-- maximally-disjoint-union
local a --: true | 42 | 'foobar' | thread | userdata | (function()) | {string}
--! ok

--8<-- union-assert-or-1
--# open `internal kailua_test`
local a = kailua_test.gen_tvar()
-- a is unresolved
local s = '' --: boolean|string
-- `s or a` forces an unresolved a to have the same type to the truthy part of s
local u = s or a --: true|string
-- so that a's type is now known
local b = a --: true|string
a = b
--! ok

--8<-- union-assert-or-2
--# open `internal kailua_test`
local a = kailua_test.gen_tvar()
-- a is unresolved
local t = {a}
local s = {''} --: {boolean|string}
-- `s or t` forces an unresolved t to have the same type to the truthy part of s
local u = s or t --: {boolean|string}
-- so that a's type is now known
local b = a --: {true|string}
a = b
--! ok

--8<-- union-assert-return -- feature:!no_implicit_func_sig
function x(q, a)
    if q then
        return 42
    else
        -- a is forced to have the same type to the previous return type `true`
        return a
    end
end
local y = x(true, false)
--@^ Error: The type `function(<unknown type>, integer) --> integer` cannot be called
--@^^ Cause: Second function argument `false` is not a subtype of `integer`
--! error

--8<-- table-assign-just
({a=1, b=2}).c = 3
--! ok

--8<-- table-assign-const
local p = {} --: const {}
p.a = 42 --@< Error: Cannot update the immutable type `const {}` by indexing
--! error

--8<-- table-assign-const-nested
local p = {a = {}, b = {}} --: {a = {}, b = const {}}
p.a.x = 42
p.b.y = 54 --@< Error: Cannot update the immutable type `const {}` by indexing
--! error

--8<-- table-assign-type-1
local p = {}
p.a = 42 --: 42|43
p.a = 43
--! ok

--8<-- table-assign-type-2
local p = {}
p.a = 42 --: 42|43
p.a = 44 --@< Error: Cannot assign `44` into `(42|43)`
         --@^ Note: The other type originates here
--! error

--8<-- table-assign-type-dup
local p = {}
p.a = 42 --: 42|43
p.a = 42 --: integer --@< Error: Cannot specify the type of indexing expression
--! error

--8<-- table-assign-type-to-vector
local p = {} --: vector<integer>
p[1] = 42 --: integer --@< Error: Cannot specify the type of indexing expression
--! error

--8<-- table-assign-type-to-map
local p = {} --: map<string, integer>
p.a = 42 --: integer --@< Error: Cannot specify the type of indexing expression
--! error

--8<-- implicit-literal-type
local x = 42
x = 54
local y = 'string'
y = 'another string'
local z = true
z = false
--! ok

--8<-- implicit-literal-type-in-record
local a = {}
a.x = 42
a.x = 54
a.y = 'string'
a.y = 'another string'
a.z = true
a.z = false
--! ok

--8<-- implicit-literal-type-in-func-args -- feature:!no_implicit_func_sig
-- XXX this essentially depends on the accuracy of constraint solver,
-- which we chose not to concern when we are not explicit about types
local function f(x, y, z)
    x = 42
    x = 54 --@< Error: Cannot assign `54` into `<unknown type>`
           --@^ Note: The other type originates here
    y = 'string'
    y = 'another string' --@< Error: Cannot assign `"another string"` into `<unknown type>`
                         --@^ Note: The other type originates here
    z = true
    z = false  --@< Error: Cannot assign `false` into `<unknown type>`
               --@^ Note: The other type originates here
end
f(0, '', false) --@< Error: The type `function(<unknown type>, <unknown type>, <unknown type>) --> ()` cannot be called
                --@^ Cause: First function argument `0` is not a subtype of `<unknown type>`
--! error

--8<-- explicit-literal-type
local x = 42 --: 42
x = 54 --@< Error: Cannot assign `54` into `42`
       --@^ Note: The other type originates here
local y = 'string' --: 'string'
y = 'another string' --@< Error: Cannot assign `"another string"` into `"string"`
                     --@^ Note: The other type originates here
local z = true --: true
z = false --@< Error: Cannot assign `false` into `true`
          --@^ Note: The other type originates here
--! error

--8<-- explicit-literal-type-in-record
local a = {}
a.x = 42 --: 42
a.x = 54 --@< Error: Cannot assign `54` into `42`
         --@^ Note: The other type originates here
a.y = 'string' --: 'string'
a.y = 'another string' --@< Error: Cannot assign `"another string"` into `"string"`
                       --@^ Note: The other type originates here
a.z = true --: true
a.z = false --@< Error: Cannot assign `false` into `true`
            --@^ Note: The other type originates here
--! error

--8<-- explicit-literal-type-in-func-args-1
--v function(x: 42, y: 'string', z: true)
local function f(x, y, z)
    x = 42
    x = 54 --@< Error: Cannot assign `54` into `42`
           --@^ Note: The other type originates here
    y = 'string'
    y = 'another string' --@< Error: Cannot assign `"another string"` into `"string"`
                         --@^ Note: The other type originates here
    z = true
    z = false --@< Error: Cannot assign `false` into `true`
              --@^ Note: The other type originates here
end
f(0, '', false) --@< Error: The type `function(42, "string", true) --> ()` cannot be called
                --@^ Cause: First function argument `0` is not a subtype of `42`
--! error

--8<-- explicit-literal-type-in-func-args-2
--v function(x: 42|54, y: 'string'|'another string', z: boolean)
local function f(x, y, z)
    x = 42
    x = 54
    y = 'string'
    y = 'another string'
    z = true
    z = false
end
f(0, '', false) --@< Error: The type `function((42|54), ("another string"|"string"), boolean) --> ()` cannot be called
                --@^ Cause: First function argument `0` is not a subtype of `(42|54)`
--! error

--8<-- explicit-literal-type-in-func-args-3
--v function(x: integer, y: string, z: boolean)
local function f(x, y, z)
    x = 42
    x = 54
    y = 'string'
    y = 'another string'
    z = true
    z = false
end
f(0, '', false)
--! ok

--8<-- kailua-test-gen-tvar
--# open `internal kailua_test`

local a = kailua_test.gen_tvar()
local b = a --: integer
local c = a --: integer
local d = a --: string --@< Error: Cannot assign `<unknown type>` into `string`
                       --@^ Note: The other type originates here

local a = kailua_test.gen_tvar()
local b = a --: string
local c = a --: integer --@< Error: Cannot assign `<unknown type>` into `integer`
                        --@^ Note: The other type originates here

--! error

--8<-- kailua-test-assert-tvar
--# open `internal kailua_test`

-- concrete type
kailua_test.assert_tvar('string')
--@^ Error: Internal Error: A type `"string"` is not a type variable
local p = 'string'
kailua_test.assert_tvar(p)
--@^ Error: Internal Error: A type `string` is not a type variable

-- type variable (that is later inferred to a concrete type, which doesn't matter)
local a = kailua_test.gen_tvar()
kailua_test.assert_tvar(a)
a = 'string'
kailua_test.assert_tvar(a)
--! error

--8<-- assume-scope
local x --: string
do
    --# assume x: integer
    x = 42
end
local y = x + 42 --@< Error: Cannot apply + operator to `string` and `42`
                 --@^ Cause: `string` is not a subtype of `number`
--! error

--8<-- assume-field
local x = {}
--# assume x.y: integer
local z = x.y + 42 --: integer
--! ok

--8<-- assume-field-scope
local x = {}
do
    --# assume x.y: integer
    x.y = 42
end
local y = x.y + 42 --@< Error: Cannot index `{}` with `"y"`
--! error

--8<-- assume-field-overwrite
local x = {y = 'string'}
--# assume x.y: integer
local z = x.y + 42 --: integer
--! ok

--8<-- assume-field-nested
local x = {}
--# assume x.y: {}
--# assume x.y.z: {}
--# assume x.y.z.u: integer
local v = x.y.z.u + 42 --: integer
--! ok

--8<-- assume-field-inferred
--# open `internal kailua_test`
local x = {}
x.y = {}
kailua_test.assert_tvar(x.y)
--# assume x.y.z: integer
local q = x.y.z + 3 --: integer
--! ok

--8<-- assume-field-whatever
--# assume x: WHATEVER
--# assume x.y: integer -- unlike most cases, WHATEVER is an error here
--@^ Error: `--# assume` directive tried to access a field from a non-table type `WHATEVER`
local z = x.y + 42 --: integer
--! error

--8<-- assume-field-missing-1
local x = 54
--# assume x.y: integer
--@^ Error: `--# assume` directive tried to access a field from a non-table type `integer`
local z = x.y + 42 --: integer
--! error

--8<-- assume-field-missing-2
local x = {}
--# assume x.y.z: integer
--@^ Error: `--# assume` directive tried to access a missing field
local z = x.y.z + 42 --: integer
--! error

--8<-- assume-field-unknown
--# open `internal kailua_test`
local x = kailua_test.gen_tvar()

--# assume x.y.z: integer
--@^ Error: `--# assume` directive tried to access a field from a type not yet known enough
local z = x.y.z + 42 --: integer
--! error

--8<-- dead-code -- feature:warn_on_dead_code
function f()
    local a = 42
    do
        do
            local b = 42
            for i = 1, 10 do
                if i < 5 then
                    break
                end
                do
                    break
                end
                local c --@< Warning: This code will never execute
            end
            return
        end
        local d --@< Warning: This code will never execute
    end
    --@v-vvvv Warning: This code will never execute
    local e = a --: string --@< Error: Cannot assign `integer` into `string`
                           --@^ Note: The other type originates here
    local f = a
    local g = a
end
do
    f()
    f()
    return
end
local z --@< Warning: This code will never execute
--! error

--8<-- lua51-table-insert-1
--# open lua51
local x = {} --: vector<integer>
table.insert(x, 42)
table.insert(x, 54)
--! ok

-->8-- lua51-table-insert-2
--# open lua51
local x = {} --: vector<integer>
table.insert(x, 42)
table.insert(x, 'not an integer') -- should error, but current definition is rather weak
--! error

--8<-- lua51-table-maxn
--# open lua51
local x = {1, 2, 3} --: vector<integer>
local y = {'foo', 'bar'} --: vector<string>
local n = table.maxn(x) --: integer
local m = table.maxn(y) --: integer
--! ok

