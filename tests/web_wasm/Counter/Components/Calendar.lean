import Counter.Common

namespace Counter

structure CalendarMonth where
  name : String
  year : Nat
  base : Nat
  days : Nat
  leading : Array Nat
  trailing : Array Nat

def CalendarMonth.title (m : CalendarMonth) : String :=
  m.name ++ " " ++ natString m.year

def calendarMonths : Array CalendarMonth := #[
  {
    name := "May",
    year := 2026,
    base := 0,
    days := 31,
    leading := #[26, 27, 28, 29, 30],
    trailing := #[1, 2, 3, 4, 5, 6]
  },
  {
    name := "June",
    year := 2026,
    base := 32,
    days := 30,
    leading := #[31],
    trailing := #[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  },
  {
    name := "July",
    year := 2026,
    base := 64,
    days := 31,
    leading := #[28, 29, 30],
    trailing := #[1, 2, 3, 4, 5, 6, 7, 8]
  }
]

theorem calendar_month_count_checked : calendarMonths.size = 3 := rfl

def defaultMonth : CalendarMonth := {
  name := "July",
  year := 2026,
  base := 64,
  days := 31,
  leading := #[28, 29, 30],
  trailing := #[1, 2, 3, 4, 5, 6, 7, 8]
}

def calendarMonthIndex (state : UInt32) : Nat :=
  if state < 32 then 0
  else if state < 64 then 1
  else 2

def calendarMonthAt (idx : Nat) : CalendarMonth :=
  calendarMonths.getD idx defaultMonth

def currentCalendarMonth (state : UInt32) : CalendarMonth :=
  calendarMonthAt (calendarMonthIndex state)

def calendarTitle (state : UInt32) : String :=
  (currentCalendarMonth state).title

def stateDay (state : UInt32) : Nat :=
  let month := currentCalendarMonth state
  (state.toNat - month.base) + 1

def clampDay (m : CalendarMonth) (day : Nat) : Nat :=
  if day < 1 then 1 else min day m.days

def encodeDate (idx day : Nat) : UInt32 :=
  let month := calendarMonthAt idx
  UInt32.ofNat (month.base + (clampDay month day - 1))

def calendarPrevMonth (state : UInt32) : UInt32 :=
  let idx := calendarMonthIndex state
  let prevIdx := if idx == 0 then 0 else idx - 1
  encodeDate prevIdx (stateDay state)

def calendarNextMonth (state : UInt32) : UInt32 :=
  let idx := calendarMonthIndex state
  let nextIdx := if idx + 1 < calendarMonths.size then idx + 1 else idx
  encodeDate nextIdx (stateDay state)

def selectedDayLabel (state : UInt32) : String :=
  let month := currentCalendarMonth state
  month.name ++ " " ++ natString (stateDay state)

def dayAction (day : Nat) : String :=
  natString (100 + day)

def selectCalendarDay (day state : UInt32) : UInt32 :=
  encodeDate (calendarMonthIndex state) day.toNat

@[export lean_next_calendar]
def nextCalendar (action state : UInt32) : UInt32 :=
  if action == 1 then
    calendarPrevMonth state
  else if action == 2 then
    calendarNextMonth state
  else if action > 100 && action <= 131 then
    selectCalendarDay (action - 100) state
  else
    state

def calendarOutsideHtml (day : Nat) : String :=
  "<span class=\"calendar-day outside\">" ++ natString day ++ "</span>"

def calendarCurrentHtml (state : UInt32) (day : Nat) : String :=
  let selected := if day == stateDay state then " selected" else ""
  "<button class=\"calendar-day" ++ selected ++ "\" type=\"button\" data-lean-state=\"calendar\" data-lean-action=\"" ++
    dayAction day ++ "\">" ++ natString day ++ "</button>"

def daysInMonth (m : CalendarMonth) : Array Nat :=
  natRangeFrom 1 m.days

def calendarGridHtml (state : UInt32) : String :=
  let month := currentCalendarMonth state
  concatMapHtml month.leading calendarOutsideHtml ++
  concatMapHtml (daysInMonth month) (calendarCurrentHtml state) ++
  concatMapHtml month.trailing calendarOutsideHtml

def calendarNavButtonHtml (label action : String) (enabled : Bool) : String :=
  if enabled then
    "<button class=\"button ghost\" type=\"button\" data-lean-state=\"calendar\" data-lean-action=\"" ++ action ++ "\">" ++ label ++ "</button>"
  else
    "<button class=\"button ghost\" type=\"button\" disabled>" ++ label ++ "</button>"

def calendarWeekHeaderHtml : String :=
  concatMapHtml #[ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ] (fun day => "<span>" ++ day ++ "</span>")

def componentCalendarHtml (state : UInt32) : String :=
  let idx := calendarMonthIndex state
  componentHeaderHtml "Calendar" "Lean owns month navigation, selected day, outside days, and the rendered grid." ++
  "<div class=\"component-preview\">" ++
    "<div class=\"calendar-head\">" ++
      calendarNavButtonHtml "Prev" "1" (idx > 0) ++
      "<strong>" ++ calendarTitle state ++ "</strong>" ++
      calendarNavButtonHtml "Next" "2" (idx + 1 < calendarMonths.size) ++
    "</div>" ++
    "<div class=\"calendar-week\" style=\"display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:6px\">" ++ calendarWeekHeaderHtml ++ "</div>" ++
    "<div class=\"calendar-grid\" style=\"display:grid;grid-template-columns:repeat(7,minmax(32px,1fr));gap:6px\">" ++ calendarGridHtml state ++ "</div>" ++
    "<p class=\"component-note\">Selected by Lean: " ++ selectedDayLabel state ++ "</p>" ++
  "</div>"

end Counter
