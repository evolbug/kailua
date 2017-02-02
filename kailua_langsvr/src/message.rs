use std::error::Error;

define_msg! { pub CannotReadConfig<'a> { error: &'a Error }:
    "ko" => "프로젝트에서 `.vscode/kailua.json`을 읽을 수 없습니다. \
             이번 세션에서 타입 체크가 비활성화됩니다. (이유: {error})",
    _    => "Cannot read `.vscode/kailua.json` in the project; \
             type checking is disabled for this session. (Cause: {error})",
}

define_msg! { pub NoStartPath:
    "ko" => "`.vscode/kailua.json`에 시작 경로가 지정되어 있지 않습니다. \
             이번 세션에서 타입 체크가 비활성화됩니다.",
    _    => "There is no start path specified in `.vscode/kailua.json`; \
             type checking is disabled for this session.",
}
