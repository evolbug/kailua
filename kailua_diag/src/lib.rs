extern crate term;
extern crate unicode_width;
#[macro_use] extern crate parse_generics_shim;
#[macro_use] extern crate log;
#[cfg(windows)] extern crate winapi;
#[cfg(windows)] extern crate kernel32;

pub use message::{Localize, Localized, get_message_language};
pub use source::{Unit, Pos, Span, Spanned, WithLoc};
pub use source::{Source, SourceFile, SourceData, SourceDataIter, SourceLineSpans};
pub use report::{Kind, Stop, Result, Report, ReportMore, Reporter};
pub use report::{ConsoleReport, CollectedReport, NoReport, TrackMaxKind};

mod message;
mod source;
mod report;
mod dummy_term;

