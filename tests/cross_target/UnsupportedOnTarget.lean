/- Library: declare a synthetic banned decl for the unsupported-target test. -/
import Lean.Compiler.UnsupportedOnTargetCmd

@[extern "test_banned_extern"] opaque testBannedDecl : IO Unit

register_unsupported_on_target testBannedDecl "test-banned-*" "synthetic test deny-list entry"
