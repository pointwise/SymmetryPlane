#
# Copyright 2009 (c) Pointwise, Inc.
# All rights reserved.
# 
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

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

  pack [label $f.logo -image [pwLogo] -bd 0 -relief flat] \
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

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

buildGui
tkwait window .

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED BY
# APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY FOR
# ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES WHATSOEVER
# (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS
# INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR
# INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE FAULT OR NEGLIGENCE OF
# POINTWISE.
#

