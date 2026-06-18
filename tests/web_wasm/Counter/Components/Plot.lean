import Counter.Common

namespace Counter

structure PlotLevel where
  label : String
  scale : String

def amplitudeLevels : Array PlotLevel := #[
  { label := "0.20x", scale := "0.20" },
  { label := "0.30x", scale := "0.30" },
  { label := "0.40x", scale := "0.40" },
  { label := "0.50x", scale := "0.50" },
  { label := "0.60x", scale := "0.60" },
  { label := "0.70x", scale := "0.70" },
  { label := "0.80x", scale := "0.80" },
  { label := "0.90x", scale := "0.90" },
  { label := "1.00x", scale := "1" },
  { label := "1.10x", scale := "1.10" }
]

def defaultAmplitudeLevel : PlotLevel := { label := "1.00x", scale := "1" }

def amplitudeMax : Nat := amplitudeLevels.size
def frequencyMax : Nat := 12

def plotStateNat (upper : Nat) (value : UInt32) : Nat :=
  let n := value.toNat
  if n < 1 then 1 else min n upper

def clampPlotState (upper : Nat) (value : UInt32) : UInt32 :=
  UInt32.ofNat (plotStateNat upper value)

def plotLevelAt (levels : Array PlotLevel) (defaultLevel : PlotLevel) (state : UInt32) : PlotLevel :=
  levels.getD (plotStateNat levels.size state - 1) defaultLevel

def amplitudeLevel (state : UInt32) : PlotLevel :=
  plotLevelAt amplitudeLevels defaultAmplitudeLevel state

def frequencyValue (state : UInt32) : Nat :=
  plotStateNat frequencyMax state

@[export lean_next_amplitude]
def nextAmplitude (value _state : UInt32) : UInt32 :=
  clampPlotState amplitudeMax value

@[export lean_next_frequency]
def nextFrequency (value _state : UInt32) : UInt32 :=
  clampPlotState frequencyMax value

def plotStateString (upper : Nat) (state : UInt32) : String :=
  natString (plotStateNat upper state)

def amplitudeLabel (state : UInt32) : String :=
  (amplitudeLevel state).label

def amplitudeScale (state : UInt32) : String :=
  (amplitudeLevel state).scale

def frequencyLabel (state : UInt32) : String :=
  let cycles := frequencyValue state
  natString cycles ++ if cycles == 1 then " cycle" else " cycles"

def unitSineY : Array Nat := #[
  80, 66, 53, 41, 30, 21, 15, 11,
  10, 11, 15, 21, 30, 41, 53, 66,
  80, 94, 107, 119, 130, 139, 145, 149,
  150, 149, 145, 139, 130, 119, 107, 94
]

def sinePeriod : Nat := 32

def wrapSineIndex (index : Nat) : Nat :=
  go index index
where
  go : Nat -> Nat -> Nat
    | 0, _ => 0
    | fuel + 1, value =>
      if value < sinePeriod then value else go fuel (value - sinePeriod)

def sineY (index : Nat) : Nat :=
  unitSineY.getD (wrapSineIndex index) 80

def plotLastSample : Nat := 64

def plotSampleCount : Nat := plotLastSample + 1

def sinePoint (frequency sample : Nat) : String :=
  let x := natMulSmall sample 5
  let waveIndex := natMulSmall (natMulSmall sample frequency) sinePeriod / plotLastSample
  let y := sineY waveIndex
  natString x ++ "," ++ natString y

def sinePoints (frequency : UInt32) : String :=
  go plotSampleCount 0 ""
where
  go : Nat -> Nat -> String -> String
    | 0, _, acc => acc
    | n + 1, sample, acc =>
      let point := sinePoint (frequencyValue frequency) sample
      let next := if sample == 0 then point else acc ++ " " ++ point
      go n (sample + 1) next

def plotSvgHtml (amplitude frequency : UInt32) : String :=
  "<svg class=\"sine-plot\" viewBox=\"0 0 320 160\" role=\"img\" aria-label=\"Lean rendered sine wave\">" ++
    "<line class=\"plot-axis\" x1=\"0\" y1=\"80\" x2=\"320\" y2=\"80\"></line>" ++
    "<g transform=\"translate(0 80) scale(1 " ++ amplitudeScale amplitude ++ ") translate(0 -80)\">" ++
      "<polyline class=\"sine-wave\" points=\"" ++ sinePoints frequency ++ "\"></polyline>" ++
    "</g>" ++
  "</svg>"

def componentPlotHtml (amplitude frequency : UInt32) : String :=
  componentHeaderHtml "Sine plot" "Lean renders the SVG path from amplitude and frequency slider state." ++
  "<div class=\"component-preview plot-preview\">" ++
    "<div id=\"plot-svg-slot\">" ++ plotSvgHtml amplitude frequency ++ "</div>" ++
    "<label class=\"slider-row\"><span>Amplitude <strong id=\"plot-amplitude-label\">" ++ amplitudeLabel amplitude ++ "</strong></span>" ++
      "<input type=\"range\" min=\"1\" max=\"" ++ natString amplitudeMax ++ "\" step=\"1\" value=\"" ++ plotStateString amplitudeMax amplitude ++ "\" data-lean-state=\"amplitude\"></label>" ++
    "<label class=\"slider-row\"><span>Frequency <strong id=\"plot-frequency-label\">" ++ frequencyLabel frequency ++ "</strong></span>" ++
      "<input type=\"range\" min=\"1\" max=\"" ++ natString frequencyMax ++ "\" step=\"1\" value=\"" ++ plotStateString frequencyMax frequency ++ "\" data-lean-state=\"frequency\"></label>" ++
  "</div>"

@[export lean_render_plot]
def renderPlot (_calendarState _todoState _events amplitude frequency : UInt32) : BaseIO Unit := do
  Std.Web.setHtml "plot-svg-slot" (plotSvgHtml amplitude frequency)
  Std.Web.setText "plot-amplitude-label" (amplitudeLabel amplitude)
  Std.Web.setText "plot-frequency-label" (frequencyLabel frequency)

end Counter
