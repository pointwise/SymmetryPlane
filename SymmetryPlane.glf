#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

###############################################################################
##
## SymmetryPlane.glf
##
## Prompt the user for a symmetry plane and tolerance and project all
## connectors within the tolerance (but not on the plane) to the plane.
##
###############################################################################

package require PWI_Glyph 2

pw::Script loadTk

#
# Plane equation:  Ax + By + Cz + D = 0
#
set symPlane(A) 0.0
set symPlane(B) 1.0
set symPlane(C) 0.0
set symPlane(D) 0.0
set symPlane(validA) 1
set symPlane(validB) 1
set symPlane(validC) 1
set symPlane(validD) 1
set symPlane(validTol) 1
set symPlane(normal) [list $symPlane(A) $symPlane(B) $symPlane(C)]
set symPlane(Tol) [pw::Grid getNodeTolerance]
set symPlane(includeDoms) 0
set symPlane(asNeeded) 1

############################################################################
# conNeedToProject: check to see if a connector needs to be projected
############################################################################
proc conNeedToProject { con } {
  global symPlane

  set numPts [$con getDimension]
  set result 0
  for {set n 1} {$n <= $numPts} {incr n} {
    # Get the distance to the plane in $delta
    set dist [pwu::Vector3 dot $symPlane(normal) [$con getXYZ -grid $n]]
    set delta [expr {abs($dist + $symPlane(D))}]
    # If a point is further away from the plane than the tolerance, it is
    # not a candidate and we do not need to check further
    if {$delta > $symPlane(Tol)} {
      return -1
    }
    # The point is within the tolerance.  If it is not zero, we need to
    # project (or if we want to force)
    if {0 == $symPlane(asNeeded) || $delta > 0.0} {
      set result 1
    }
  }
  return $result
}

############################################################################
# domNeedToProject: check to see if a domain needs to be projected
############################################################################
proc domNeedToProject { dom } {
  global symPlane

  set dims [$dom getDimensions]
  set result 0
  # Structured case
  if [$dom isOfType pw::DomainStructured] {
    set iMax [lindex $dims 0]
    set jMax [lindex $dims 1]
    for {set j 1} {$j <= $jMax} {incr j} {
      for {set i 1} {$i <= $iMax} {incr i} {
        # Get the distance to the plane in $delta
        set dist [pwu::Vector3 dot $symPlane(normal) \
          [$dom getXYZ -grid [list $i $j]]]
        set delta [expr {abs($dist + $symPlane(D))}]
        # If a point is further away from the plane than the tolerance, it is
        # not a candidate and we do not need to check further
        if {$delta > $symPlane(Tol)} {
          return -1
        }
        # The point is within the tolerance.  If it is not zero, we need to
        # project (or if we want to force)
        if {0 == $symPlane(asNeeded) || $delta > 0.0} {
          set result 1
        }
      }
    }
  # Unstructured case
  } elseif [$dom isOfType pw::DomainUnstructured] {
    set iMax [lindex $dims 0]
    for {set i 1} {$i <= $iMax} {incr i} {
      # Get the distance to the plane in $delta
      set dist [pwu::Vector3 dot $symPlane(normal) [$dom getXYZ -grid $i]]
      set delta [expr {abs($dist + $symPlane(D))}]
      # If a point is further away from the plane than the tolerance, it is
      # not a candidate and we do not need to check further
      if {$delta > $symPlane(Tol)} {
        return -1
      }
      # The point is within the tolerance.  If it is not zero, we need to
      # project (or if we want to force)
      if {0 == $symPlane(asNeeded) || $delta > 0.0} {
        set result 1
      }
    }
  # Unknown type
  } else {
    return -1
  }
  return $result
}

############################################################################
# cancelCB: handle user pressing the Cancel button
############################################################################
proc cancelCB { } {
  ::exit
}

############################################################################
# run: project cons and doms
############################################################################
proc run { } {
  global symPlane

  set symPlane(normal) [list $symPlane(A) $symPlane(B) $symPlane(C)]
  set conProjList [list]
  foreach con [pw::Grid getAll -type pw::Connector] {
    if {1 == [conNeedToProject $con]} {
      lappend conProjList $con
    }
  }

  set domProjList [list]
  if {$symPlane(includeDoms)} {
    foreach dom [pw::Grid getAll -type pw::Domain] {
      if {1 == [domNeedToProject $dom]} {
        lappend domProjList $dom
      }
    }
  }

  if {[llength $conProjList] == 0 && [llength $domProjList] == 0} {
    tk_messageBox -icon info -message "No entities need to be projected." \
      -title "Symmetry Plane" -type ok
  } else {
    set dbPlane [pw::Plane create]
    $dbPlane setCoefficients $symPlane(A) $symPlane(B) $symPlane(C) \
	    $symPlane(D)
    foreach con $conProjList {
      $con project -type LINEAR $dbPlane
    }
    foreach dom $domProjList {
      $dom project -type LINEAR -interior $dbPlane
    }
    $dbPlane delete -force
  }
}

############################################################################
# runCB: handle the user pressing the Run button
############################################################################
proc runCB { } {
  . configure -cursor watch
  update
  run
  ::exit
}

############################################################################
# addSeparator: add a Tk separator frame
############################################################################
proc addSeparator { name } {
  set f [frame $name -height 2 -relief sunken -borderwidth 1]
  pack $f -side top -fill x -expand TRUE
  return $f
}

############################################################################
# bottomRow: add Tk button row
############################################################################
proc bottomRow { name width args } {
  set f [frame $name]

  set buttons [list $f]
  for {set n [expr {[llength $args] - 1}]} {0 <= $n} {incr n -1} {
    foreach {label cmd} [lindex $args $n] {break}
    set b [button ${f}.b${n} -width $width -text $label -command $cmd]
    pack $b -side right -padx 5
    set buttons [linsert $buttons 1 $b]
  }

  pack [label $f.logo -image [cadenceLogo] -bd 0 -relief flat] \
      -side left -padx 5

  return $buttons
}

############################################################################
# updateRunStatus: validate input and update widgets
############################################################################
proc updateRunStatus { state index newValue } {
  global symPlane

  set A $symPlane(A)
  set B $symPlane(B)
  set C $symPlane(C)
  set D $symPlane(D)
  set Tol $symPlane(Tol)
  set $index $newValue
  set valid(A) $symPlane(validA)
  set valid(B) $symPlane(validB)
  set valid(C) $symPlane(validC)
  set valid(D) $symPlane(validD)
  set valid(Tol) $symPlane(validTol)
  set valid($index) $state

  if {$valid(A) && $valid(B) && $valid(C) && $valid(D)} {
    if {0.0 == $A && 0.0 == $B && 0.0 == $C} {
      set valid(A) 0
      set valid(B) 0
      set valid(C) 0
    }
  }
  if {$valid(Tol) && $Tol <= 0.0} {
    set valid(Tol) 0
  }

  set state 1
  foreach i [list A B C D Tol] {
    if {$valid($i)} {
      $symPlane(widget$i) configure -background $symPlane(bg)
    } else {
      $symPlane(widget$i) configure -background "#ffc0c0"
      set state 0
    }
  }

  $symPlane(run) configure -state [lindex {"disabled" "normal"} $state]
}

############################################################################
# validateCB: handle user input changes
############################################################################
proc validateCB { index newValue } {
  global symPlane

  if {[string is double $newValue] && ![string equal "" $newValue]} {
    set symPlane(valid$index) 1
    $symPlane(widget$index) configure -background $symPlane(bg)
  } else {
    set symPlane(valid$index) 0
    $symPlane(widget$index) configure -background "#ffc0c0"
  }

  updateRunStatus $symPlane(valid$index) $index $newValue
  return 1
}

############################################################################
# principalCB: handle user changing principal plane
############################################################################
proc principalCB { values } {
  global symPlane

  foreach {symPlane(A) symPlane(B) symPlane(C) symPlane(D)} $values {break}
  set symPlane(validA) 1
  set symPlane(validB) 1
  set symPlane(validC) 1
  set symPlane(validD) 1
  updateRunStatus 1 A $symPlane(validA)
}

############################################################################
# buildGui: build the Tk window
############################################################################
proc buildGui { } {
  global symPlane

  # Title bar
  wm title . "Symmetry Plane"
  set top [frame .top]
  set f [frame $top.titleFrame]
  pack $f -side top -fill x -pady 5
  set l [label $f.label -text "Symmetry Plane" -justify center]
  set font [$l cget -font]
  set fontFamily [font actual $font -family]
  set fontSize [font actual $font -size]
  set bigLabelFont [font create -family $fontFamily -weight bold \
    -size [expr {int(1.5 * $fontSize)}]]
  $l configure -font $bigLabelFont
  set regLabelFont [font create -family $fontFamily -weight bold \
    -size [expr {int(1.25 * $fontSize)}]]
  pack $l -side top

  # Separator
  addSeparator $top.hr1

  # Equation entry
  set f [frame $top.eqFrame]
  set w 8
  set l [label $f.label -text "Plane Equation" -justify center \
    -font $regLabelFont]
  pack $l -side top
  set symPlane(widgetA) [entry $f.aEntry -textvar symPlane(A) -width $w -justify right]
  set l [label $f.eq1 -text "x + " -justify left -font $regLabelFont]
  pack $symPlane(widgetA) $l -side left
  set symPlane(widgetB) [entry $f.bEntry -textvar symPlane(B) -width $w -justify right]
  set l [label $f.eq2 -text "y + " -justify left -font $regLabelFont]
  pack $symPlane(widgetB) $l -side left
  set symPlane(widgetC) [entry $f.cEntry -textvar symPlane(C) -width $w -justify right]
  set l [label $f.eq3 -text "z + " -justify left -font $regLabelFont]
  pack $symPlane(widgetC) $l -side left
  set symPlane(widgetD) [entry $f.dEntry -textvar symPlane(D) -width $w -justify right]
  set l [label $f.eq4 -text " = 0" -justify left -font $regLabelFont]
  pack $symPlane(widgetD) $l -side left
  pack $f -side top -pady 5 -padx 5

  set symPlane(bg) [$symPlane(widgetA) cget -background]

  # Spacer
  set f [frame $top.spacer1 -height 5]
  pack $f -side top

  # Tolerance
  set f [frame $top.tolerance]
  set l [label $f.label -text "Tolerance" -justify right]
  set symPlane(widgetTol) [entry $f.entry -textvariable symPlane(Tol) -width $w]
  pack $l $symPlane(widgetTol) -side left -pady 5
  pack $f -side top

  # Options
  set f [frame $top.options]
  set b [checkbutton $f.asNeeded -text "Only If Needed" \
    -variable symPlane(asNeeded)]
  pack $b -side left -padx 5 -pady 5
  set b [checkbutton $f.dom -text "Domains" -variable symPlane(includeDoms)]
  pack $b -side left -padx 5 -pady 5
  pack $f -side top

  # Separator
  addSeparator $top.hrPrinc

  # Principal plane buttons
  set w 4
  set f [frame $top.principal]
  set l [label $f.label -text "Principal Planes" -justify center \
    -font $regLabelFont]
  pack $l -side top
  set bYZ [button $f.yz -text "X=0" -width $w \
    -command [list principalCB {1.0 0.0 0.0 0.0}]]
  set bXZ [button $f.xz -text "Y=0" -width $w \
    -command [list principalCB {0.0 1.0 0.0 0.0}]]
  set bXY [button $f.xy -text "Z=0" -width $w \
    -command [list principalCB {0.0 0.0 1.0 0.0}]]
  pack $bYZ $bXZ $bXY -side left -padx 5 -pady 5
  pack $f -side top

  # Separator
  addSeparator $top.hrBottom

  # Create the bottom buttons
  set buttons [bottomRow $top.cmdRow 8 {"Run" runCB} {"Cancel" cancelCB}]
  pack [lindex $buttons 0] -side bottom -fill x -expand FALSE -pady 5
  set symPlane(run) [lindex $buttons 1]

  # Set text validation functions for equation entry widgets
  foreach b [list A B C D Tol] {
    $symPlane(widget$b) configure -validate all -vcmd [list validateCB $b %P]
  }

  bind . <Control-KeyPress-Return> { .top.cmdRow.b0 invoke }
  bind . <KeyPress-Escape> { .top.cmdRow.b1 invoke }

  # Finally, show the window
  pack $top -expand TRUE -fill both

  # Center the window
  ::tk::PlaceWindow . widget

  set w [winfo reqwidth .]
  set h [winfo reqheight .]
  wm resizable . 1 0
  wm minsize . $w $h
}

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

buildGui
tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
