/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

prelude
public import Init.Data.String.Basic
public import Init.System.IO
public import Std.Web.Unsupported

public section

namespace Std.Web

@[extern "lean_web_console_log", never_extract]
opaque consoleLogImpl (s : @& String) : BaseIO Unit

@[inline]
def consoleLog (s : String) : BaseIO Unit :=
  consoleLogImpl s

@[extern "lean_web_set_text", never_extract]
opaque setTextImpl (id : @& String) (text : @& String) : BaseIO Unit

@[inline]
def setText (id text : String) : BaseIO Unit :=
  setTextImpl id text

@[extern "lean_web_set_html", never_extract]
opaque setHtmlImpl (id : @& String) (html : @& String) : BaseIO Unit

@[inline]
def setHtml (id html : String) : BaseIO Unit :=
  setHtmlImpl id html

@[extern "lean_web_get_value", never_extract]
opaque getValueImpl (id : @& String) : BaseIO String

@[inline]
def getValue (id : String) : BaseIO String :=
  getValueImpl id

@[extern "lean_web_set_value", never_extract]
opaque setValueImpl (id : @& String) (value : @& String) : BaseIO Unit

@[inline]
def setValue (id value : String) : BaseIO Unit :=
  setValueImpl id value

end Std.Web
