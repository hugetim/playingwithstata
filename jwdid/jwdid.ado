*! v1.31 Corrects for Never group
* v1.3 Corrects for Nonlinear models
* 8/30/2022 corrects for long variables
* v1.2 FRA 8/17/2022 Adds Correction unbalanced panel
* v1.1 FRA 8/5/2022 Redef not yet treated. 
* v1   FRA 8/5/2022 Has almost everything we need

program jwdid, eclass
	version 14
	syntax varlist [if] [in] [pw], [Ivar(varname) cluster(varname) ] Tvar(varname) Gvar(varname) [never group method(name) nocorr]
	marksample  touse
	markout    `touse' `ivar' `tvar' `gvar'
	gettoken y x:varlist 
	
	easter_egg
	** Count gvar
	/*qui:count if `gvar'==0 & `touse'==1 
	if `r(N)'==0 {
		*qui:sum `gvar' if `touse'==1 , meanonly
		
	}*/
	** Take out of sample units that have always been treated.
	tempvar tvar2
	qui:bysort `touse' `ivar': egen long `tvar2'=min(`tvar')
	qui:replace `touse'=0 if `touse'==1 & `tvar2'>=`gvar' & `gvar'!=0 & `tvar'>=`gvar'
	
	** If no never treated
	qui:count if `gvar'==0 & `touse'==1 
	if `r(N)'==0 {
		qui:sum `gvar' if `touse'==1 , meanonly
		qui:replace `touse'=0 if `touse'==1 & `tvar'>=`r(max)' 
	}
	
	qui:capture drop __tr__
	qui:gen byte __tr__=0 if `touse'
	qui:replace  __tr__=1 if `tvar'>=`gvar' & `gvar'>0  & `touse'
	qui:replace  __tr__=1 if `touse' & "`never'"!=""
	qui:capture drop __etr__
	qui:gen byte __etr__=0 if `touse'
	qui:replace  __etr__=1 if `touse' & `tvar'>=`gvar' & `gvar'>0
	
	qui:levels `gvar' if `touse' & `gvar'>0, local(glist)
	sum `tvar' if `touse' , meanonly
	qui:levels `tvar' if `touse' & `tvar'>=r(min), local(tlist)
	
	** Center Covariates
	if "`weight'"!="" local wgt aw
	if "`x'"!="" {
			capture drop _x_*
			qui:hdfe `y' `x' if `touse'	[`wgt'`exp'], abs(`gvar') 	keepsingletons  gen(_x_)
			capture drop _x_`y'
			local xxvar _x_*
	}
	***
	foreach i of local glist {
		foreach j of local tlist {
			if "`never'"!="" {
				if (`i'-1)!=`j' {
				local xvar `xvar' c.__tr__#i`i'.`gvar'#i`j'.`tvar' ///
							      c.__tr__#i`i'.`gvar'#i`j'.`tvar'#c.(`xxvar') 
							  
				local xvar2 `xvar2' i`i'.`gvar'#i`j'.`tvar' 
				
				local xvar3 `xvar3' i`i'.`gvar'#i`j'.`tvar'#c.(`xxvar')  
				}
			}
			else if `j'>=`i' {
				local xvar `xvar' c.__tr__#i`i'.`gvar'#i`j'.`tvar' ///
							      c.__tr__#i`i'.`gvar'#i`j'.`tvar'#c.(`xxvar')   
							 
				local xvar2 `xvar2' i`i'.`gvar'#i`j'.`tvar' 		
				local xvar3 `xvar3' i`i'.`gvar'#i`j'.`tvar'#c.(`xxvar') 
			}

		}
	}
	** for xs
	
	foreach i of local glist {
		local ogxvar `ogxvar' i`i'.`gvar'#c.(`x')
	}
	
	foreach j of local tlist {
		local otxvar `otxvar' i`j'.`tvar'#c.(`x')
	}
 	*display in w "t:`otxvar'"
	*display in w "g:`xvar'"
	** Cluster level
	if "`cluster'"=="" & "`ivar'"=="" local cvar 
	if "`cluster'"=="" & "`ivar'"!="" local cvar `ivar'
	if "`cluster'"!="" local cvar `cluster'
	
	
	
	if "`method'"=="" {
		if "`group'"=="" {
			
			reghdfe `y' `xvar'   `otxvar'	///
				if `touse' [`weight'`exp'], abs(`ivar' `tvar') cluster(`cvar') keepsingletons	
		}	
		else {
			if "`ivar'"!="" {
				qui:xtset `ivar' `tvar'
				mata:is_balanced("`ivar' `tvar'","`touse'")
		 
				if `ibal'==0 & "`corr'"=="" {
					** Correction 
					qui:myhdmean `xvar2' `xvar3' `otxvar' i.`tvar' if `touse'	[`wgt'`exp'] , prefix(_z_) keepsingletons abs(`ivar')
					local xcorr  `r(vlist)'
				}
			}	
			reghdfe `y' `xvar'  `x'  `ogxvar' `otxvar'  `xcorr' ///
			if `touse' [`weight'`exp'], abs(`gvar'  `tvar') cluster(`cvar') keepsingletons noempty
		}
	}
	else {
		if "`ivar'"!="" {
			qui:xtset `ivar' `tvar'
			mata:is_balanced("`ivar' `tvar'","`touse'")	
			if `ibal'==0 & "`corr'"==""  {
					** Correction 
					qui:myhdmean `xvar2'  i.`tvar' if `touse'	[`wgt'`exp'] , prefix(_z_) keepsingletons abs(`ivar')
					local xcorr  `r(vlist)'				
			} 
		}
		`method'  `y' `xvar'  `x'  `ogxvar' `otxvar' `xcorr'    i.`gvar' i.`tvar' ///
		if `touse' [`weight'`exp'], cluster(`cvar') 
	}
	
	ereturn local cmd jwdid
	ereturn local cmdline jwdid `0'
	ereturn local estat_cmd jwdid_estat
	if "`never'"!="" ereturn local type  never
	else 			 ereturn local type  notyet
	ereturn local ivar `ivar'
	ereturn local tvar `tvar'
	ereturn local gvar `gvar'
	
end

mata
void is_balanced(string scalar ivars, string scalar touse){
	real matrix ivar, tvar, inf, ord
	
	ivar=st_data(.,ivars,touse)
	ord=order(ivar,(1,2))
	inf=panelsetup(ivar,1)
	// same number of observations
	real scalar max1, min1, max2 , max3, min2 , min3
	max1=max(inf[,2]:-inf[,1])
	min1=min(inf[,2]:-inf[,1])
	// same max and min
	max2=max(ivar[inf[,1],2])
	min2=min(ivar[inf[,1],2])
	max3=max(ivar[inf[,2],2])
	min3=min(ivar[inf[,2],2])
	if ( (max1==min1) & (max2==min2) & (max3==min3)) st_local("ibal","1")
	else st_local("ibal","0")
}
end

program easter_egg
	
	local date_to = date("`c(current_date)'","DMY")
	local month   = month(`date_to')
	local day     = day(`date_to')
	
	if runiform()<0.001 | (`month'==8 & `day'==6 & runiform()<0.1 ) {
	display in w "{p}Hi there, thank you for using this command. I hope you are finding this 'easter egg' as a surprised, and not because you " ///
	"decided to take a peak on the code. But if you did, shame on me for not making a better easter egg {p_end}"
	display in w "{p}Anyways, This easter egg is for my Daughter! Yes as of August 6th 2022 (Viva Bolivia) my little one was born!. " _n  ///
		"so if you happen to read this, two things happen. Either you were in the 0.1% lucky to see this, or its my little one birthday. If the latter  please send my little one, a Happy Birthday! {p_end}"
	}
end

program myhdmean, rclass
	syntax anything [if] [aw iw pw fw], abs(varlist) prefix(name) [compact  keepsingletons]
	
	ms_fvstrip `anything' `if', expand dropomit
	local vvlist `r(varlist)'
	** First check and create
	** local k =0 for names
	foreach i in `vvlist' {
		local k=`k'+1
		capture confirm variable `i'
		if _rc!=0 {
			if length(strtoname("`i'"))<25 local vn = strtoname("`i'")
			else local vn _nvar_`k'
			gen double `vn'=`i'
			label var `vn' `"`i'"'
			local dropvlist `dropvlist' `vn'
			
		}
		else local vn `i'
		
		local vflist `vflist' `vn'
	}
	
	if "`compact'"=="" {
		foreach i in `vflist' {
			local cnt
			local fex
			foreach j of varlist `abs' {
				local cnt=`cnt'+1
				capture drop `prefix'`cnt'_`i'
				local fex `fex' `prefix'`cnt'_`i'=`j'
				local vlist `vlist' `prefix'`cnt'_`i'
			}
			qui:reghdfe `i' `if'  [`weight'`exp'], abs(`fex')  `keepsingletons'
			local vlab:variable label `i'
			
			label var `prefix'`cnt'_`i' "`vlab'"
		}
		local vflist `vlist'
		local vlist
		foreach i in `vflist' {
			capture:{
				sum `i', meanonly
				if abs(`r(max)'-`r(min)')>epsfloat() local vlist `vlist' `i'
				else local dropvlist `dropvlist' `i'
			}
		}
		
		return local vlist  `vlist'
	}
	else {
		foreach i in  `vflist' {
			local cnt
			local fex
			capture drop `prefix'`cnt'_`i'
			qui:reghdfe `i' `if'  [`weight'`exp'], abs(`abs') resid `keepsingletons'
			qui:gen double `prefix'`cnt'_`i'=`i'-_reghdfe_resid-_cons
			local vlist `vlist' `prefix'`cnt'_`i'
			qui:drop _reghdfe_resid
			
		}
		
		local vflist `vlist'
		local vlist
		foreach i in `vflist' {
			sum `i', meanonly
			if abs(`r(max)'-`r(min)')>epsfloat() local vlist `vlist' `i'
			else local dropvlist `dropvlist' `i'
		}
		return local vlist   `vlist'
	}
	*display in w "`dropvlist'"
	if "`dropvlist'"!="" drop `dropvlist'
	
end