** Title: primes_pilot.do
** Author: Justin Abraham
** Desc: Cleans and analyzes pilot results
** Input: Raw Z-Tree data
** Output: Regression tables, figures, statistics, and cleaned pilot data.

////////////////////////
// Import Z-Tree data //
////////////////////////

cap cd "$input_dir/pilot"

loc datalist : dir "$input_dir/pilot" files "1603*.xls"
loc i = 1

di `datalist'

foreach data in `datalist' {

	clear
	ztree2stata subjects using `data'
	tempfile zed`i'
	save `zed`i'', replace
	loc ++i

}

use `zed1', clear

while `i' > 1 {

	cap: append using `zed`i''
	loc --i

}

/////////////////////
// Lab information //
/////////////////////

encode session, gen(temp)
drop session
ren temp session

egen surveyid = group(session Subject)

gen version = session
recode version (1 3 5 7 10 = 0) (else = 1)
la def la_version 0 "Version A" 1 "Version B"
la val version la_version

tempfile raw
save `raw', replace

////////////////////
// Poverty primes //
////////////////////

keep if treatment == 2
keep surveyid Group Likert* ShockYN

ren Group treatment
replace treatment = 2 - treatment
gen control = 1 - treatment

replace ShockYN = 2 - ShockYN

tempfile primes
save `primes', replace

/////////////////////////
// Manipulation checks //
/////////////////////////

use `raw', clear

keep if treatment == 3 | treatment == 4
keep surveyid version treatment Cantril* Worry*

reshape wide Cantril* Worry*, i(surveyid) j(treatment)

foreach var in CantrilNow CantrilFive {

	cap: gen `var' = .
	replace `var' = `var'3 if ~version
	replace `var' = `var'4 if version

}

foreach var in Worry1 Worry2 Worry3 {

	cap: gen `var' = .
	replace `var' = `var'3 if version
	replace `var' = `var'4 if ~version

}

keep surveyid CantrilNow CantrilFive Worry1 Worry2 Worry3

tempfile checks
save `checks', replace

///////////
// PANAS //
///////////

use `raw', clear

keep if treatment == 5
keep surveyid panas* stress

tempfile panas
save `panas', replace

///////////////////
// Comprehension //
///////////////////

use `raw', clear

keep if treatment == 6
keep surveyid Comp*

ren Comp1 comprehension
ren Comp2 readlanguage

tempfile comp
save `comp', replace

//////////////////////
// Assemble dataset //
//////////////////////

use `raw', clear

keep if treatment == 1
keep surveyid session version

merge 1:1 surveyid using `primes', nogen
merge 1:1 surveyid using `checks', nogen
merge 1:1 surveyid using `panas', nogen
merge 1:1 surveyid using `comp', nogen

la def la_treatment 0 "Control" 1 "Treated"
la val treatment la_treatment

la var surveyid "Subject ID"
la var session "Session"
la var version "Version"
la var treatment "Primed"
la var LikertFP "Given my situation, I would be able to support myself and my dependents."
la var ShockYN "Are there ways in which you may be able to come up with that amount of money on a very short notice?"
la var LikertShock "Coming up with KSH 15,000 (500) on a very short notice would cause me long-lasting financial hardship."
la var LikertInc1 "Given my situation, I would be able to maintain roughly the same lifestyle if my household income decreases."
la var LikertInc2 "The decrease in my income would strongly impact my daily life."
la var CantrilNow "Cantril - Present"
la var CantrilFive "Cantril - 5 Years"
la var Worry1 "I am very worried about not having enough money to make ends meet."
la var Worry2 "I am very worried about not being able to find money in case I really need it."
la var Worry3 "I am very worried about my financial situation."
la var comprehension "Understood primes"
la var readlanguage "Best language"
la var stress "Stressed"

foreach var of varlist panas_* {

	loc root = proper(substr("`var'", 7, .))
	la var `var' "`root'"

}

qui compress
save "$output_dir/primes_pilot.dta", replace

////////////////
// Estimation //
////////////////

/* Standardize scales */

foreach var of varlist Likert* Cantril* Worry* panas_* stress comprehension {

	egen `var'_z = weightave(`var'), normby(control)
	loc label: var la `var'
	la var `var'_z "`label'"

}

/* Summary statistics */

estpost tab session treatment
esttab using "$tab_dir/tab-session", booktabs unstack noobs nonumber nomtitle label nonotes mgroups("Treatment group", pattern(1 0 0 1) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) replace

twoway (hist comprehension if ~treatment, fcolor(none) lcolor(gs2) lpattern(dash)) (hist comprehension if treatment, color(gs2)), legend(order(1 "Control" 2 "Treated")) graphregion(color(white))
graph export "$fig_dir/hist-comprehension.pdf", as(pdf) replace

/* Treatment effects */

loc primes "ShockYN LikertFP LikertShock LikertInc1 LikertInc2"
loc checks "CantrilNow CantrilFive Worry1 Worry2 Worry3"
loc positive "panas_interested panas_excited panas_strong panas_enthusiastic panas_proud panas_alert panas_inspired panas_determined panas_attentive panas_active"
loc negative "panas_distressed panas_upset panas_guilty panas_scared panas_hostile panas_irritable panas_ashamed panas_nervous panas_jittery panas_afraid stress"

loc primestitle "Treatment effect on primes responses"
loc checkstitle "Treatment effect on manipulation checks"
loc positivetitle "Treatment effect on positive affect"
loc negativetitle "Treatment effect on negative affect"

foreach group in primes checks positive negative {

	loc columns = 0
	loc vardesc ""

	foreach yvar in ``group'' {

		if strpos("`yvar'", "ShockYN") == 1 eststo: reg `yvar' treatment comprehension_z i.session, vce(cluster session)
		else eststo: reg `yvar'_z treatment comprehension_z i.session, vce(cluster session)

		qui sum `yvar' if control
		estadd loc cmean = round(`r(mean)', 0.01)

		loc ++columns
		loc varla: var la `yvar'
		loc vardesc "`vardesc' (`columns') `varla'"

	}

	loc prehead "\begin{table}[htbp]\centering \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \caption{``group'title'} \label{tab:reg-`group'} \maxsizebox*{\textwidth}{\textheight}{ \begin{threeparttable} \begin{tabular}{l*{`columns'}{c}} \toprule"
	loc postfoot "\bottomrule \end{tabular} \begin{tablenotes}[flushleft] \footnotesize \item \emph{Note:} @note \end{tablenotes} \end{threeparttable} } \end{table}"
	loc footnote "Dependent variables are standardized to their control group means. `vardesc'."

	esttab using "$tab_dir/reg-`group'", booktabs nogap label se compress nobaselevels ar2 obslast nomtitle keep(treatment) scalars("cmean Control mean") star(* 0.10 ** 0.05 *** 0.01) prehead("`prehead'") postfoot("`postfoot'") note("`footnote'") replace

	eststo clear

}

/* Heterogeneous treatment effects */

* foreach xvar in readlanguage {

* 	eststo, prefix(het): reg `yvar' i.treatment##i.xvar i.session, vce(cluster session)

* }

* loc prehead "\begin{table}[htbp]\centering \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \caption{Attrition by treatment group} \label{tab:reg-subattr} \maxsizebox*{\textwidth}{\textheight}{ \begin{threeparttable} \begin{tabular}{l*{1}{c}} \toprule"
* loc postfoot "\bottomrule \end{tabular} \begin{tablenotes}[flushleft] \footnotesize \item \emph{Note:} @note \end{tablenotes} \end{threeparttable} } \end{table}"
* loc footnote "This table reports coefficient estimates for the regression of attrition on treatment assignment. Standard errors are in parentheses. * denotes significance at 10 pct., ** at 5 pct., and *** at 1 pct. level."

* esttab het* using "$tab_dir/het-`yvar'", booktabs nogap label se compress nobaselevels star(* 0.10 ** 0.05 *** 0.01) prehead("`prehead'") postfoot("`postfoot'") note("`footnote") replace


* outcomes: standardized likerts, yesno, standardized comprehension, worry index, affect index, stress
* regression with controls
* het effects by income, comprehension, language, version

