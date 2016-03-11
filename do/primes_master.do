** Title: primes_master.do
** Author: Justin Abraham
** Desc: Master .do file for the Poverty Primes lab experiment
** Input: See pointers. 

log close _all
clear all

set maxvar 20000
set matsize 11000
set more off

cap cd ../../

***********
** Setup **
***********

/* Specify directories */

glo project_dir "`c(pwd)'"						// Poverty Primes project folder
glo data_dir "$project_dir/data"	 	 		// Data
glo input_dir "$data_dir/input"					// Raw sata
glo output_dir "$data_dir/output"				// Cleaned data
glo ado_dir "$project_dir/code/ado/personal"	// .ado files
glo do_dir "$project_dir/code/do"			 	// .do files
glo fig_dir "$project_dir/figures"				// Figures
glo tab_dir "$project_dir/tables"		 		// Tables

sysdir set PERSONAL "$ado_dir"
cap cd "$data_dir"

/* Customize program */

glo pilotflag = 1		// Clean and analyze pilot data
glo cleandataflag = 0	// Clean raw Z-Tree lab data
glo summaryflag = 0		// Output summary statistics
glo figuresflag = 0		// Output graphs and figures
glo regressionflag = 0	// Estimate treatment effects

*************
** Program **
*************

glo currentdate = date("$S_DATE", "DMY")
loc stringdate : di %td_CY.N.D date("$S_DATE", "DMY")
glo stamp = trim("`stringdate'")

timer clear
timer on 1

/* Choose latest .do files */

if $pilotflag do "$do_dir/primes_pilot.do"
* if $appenddataflag do "$do_dir/primes_append.do"
* if $cleandataflag do "$do_dir/primes_clean.do"

* /* Choose latest data */

* loc dataroot "Long Wide Tracker"

* foreach root in `dataroot' {

* 	loc datalist : dir "$data_dir/`root'" files "Aspirations_Pilot_`root'_*.dta"
* 	loc mindistance = 9999

* 	foreach dta in `datalist' {

* 		loc datadate = date(substr("`dta'", -14, 10), "YMD")
* 		loc distance = $currentdate - `datadate'

* 		if `mindistance' >= `distance' {
* 			loc mindistance = `distance'
* 			glo Aspirations_Pilot_`root'_top "`root'/`dta'"
* 		}

* 	}

* }

* if $summaryflag do "$do_dir/primes_summary.do"
* if $figuresflag do "$do_dir/primes_figures.do"
* if $regressionflag do "$do_dir/primes_estimate.do"

timer off 1
qui timer list
di "Finished in `r(t1)' seconds."

log close _all

/**********
** Notes **
***********

what happened to demographics???
can salvage with busara data maybe



