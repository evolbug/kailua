-- definitions for Lua 5.1 string library

--# assume global `string`:
--#     const {
--#         `byte` = const function(string, integer?, integer?) -> (integer...);
--#         `char` = const function(integer...) -> string;
--#         `dump` = const function(function) -> string;
--#         `find` = const function(string, string, integer?, boolean?) ->
--#                                (integer, integer, string|integer...);
--#         `format` = const function(string, any...) -> string;
--#         `gmatch` = const function(string, string) -> function() -> string?;
--#         -- TODO have to constrain the function argument, but not easy
--#         `gsub` = const function(string, string,
--#                                 string | { [string] = string } | (function(WHATEVER...) -> string),
--#                                 integer?) -> string;
--#         `len` = const function(string) -> integer;
--#         `lower` = const function(string) -> string;
--#         `match` = const function(string, string, integer?) -> (string|integer...);
--#         `rep` = const function(string, integer) -> string;
--#         `reverse` = const function(string) -> string;
--#         `sub` = const function(string, integer, integer?) -> string;
--#         `upper` = const function(string) -> string;
--#     } = "string-meta"

