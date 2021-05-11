** Goal. Make the estimator modular. That way other options can be added
*! v1.0 DRDID for Stata by FRA All Estiators but IPWRA have are available for panel
* Need to add weights. 
* v0.8 DRDID for Stata by FRA Other estimators are available. Onlyone missing iwp panel
* v0.7 DRDID for Stata by FRA IPW estimator for panel (Asjad original Rep)
* v0.5 DRDID for Stata by FRA Incorporates RC1 and RC2 estimators
* v0.2 DRDID for Stata by FRA Fixes typo with tag
* v0.2 DRDID for Stata by FRA Allows for Factor notation
* v0.1 DRDID for Stata by FRA Typo with ID TIME
* For panel only for now



program define drdid, eclass sortpreserve
	syntax varlist(fv ) [if] [in], [ivar(varname)] time(varname) TReatment(varname) ///
	[noisily drimp dripw reg sipw tipw ipwra all]  
	local 00 `0'
	marksample touse
	markout `touse' `ivar' `time' `treatment'
	
	** Which option 
	if "`drimp'`dripw'`reg'`sipw'`ipwra'`all'"=="" {
	    display "No estimator selected. Using default -drimp-"
		local drimp drimp
	}
	else {
	    if `:word count `drimp' `dripw' `reg' `sipw' `ipwra' `all''!=1 {
		    display "Only one option allowed, more than 1 selected."
			error 1
		}
	}
	** First determine outcome and xvars
	gettoken y xvar:varlist
	** Sanity Checks for Time. Only 2 values
	tempvar vals
	qui:bysort `touse' `time': gen byte `vals' = (_n == 1) * `touse'
	su `vals' if `touse', meanonly 
	if  r(sum)!=2 {
	    display in red "Time variable can only have 2 values in the working sample"
		error 1
	}
	else {
		tempvar tmt
		qui:egen byte `tmt'=group(`time') if `touse'
		qui:replace `tmt'=`tmt'-1	    
	}
	
	drop `vals'
	qui:bysort `touse' `treatment': gen byte `vals' = (_n == 1) * `touse'
	su `vals' if `touse', meanonly
 
	if  r(sum)!=2 {
	    display in red "Treatment variable can only have 2 values in the working sample"
		error 1
	}
	else {
		tempvar trt
		qui:egen byte `trt'=group(`treatment') if `touse'
		qui:replace `trt'=`trt'-1
	}
	**# for panel estimator
	tempvar tag
	qui:bysort `touse' `ivar' (`time'):gen byte `tag'=_n if `touse'
	** Default will be IPT 
 	if "`drimp'"!="" {
		drdid_dript , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`dripw'"!="" {
		// DR ipw asjad
		drdid_dripw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`tipw'"!="" {
		// abadies Done
		drdid_tipw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`reg'"!="" {
		drdid_reg , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`sipw'"!="" {
		drdid_sipw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`ipwra'"!="" {
		//only one without modeling
		drdid_sipwra , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	else if "`all'"!="" {
	    display "DRDID with IPT"
	    drdid_dript , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
		display "DRDID with IPW"
	    drdid_dripw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
		display "DRDID with Abadies IPW"
	    drdid_tipw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
		display "DID with OR"
		drdid_reg , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
		display "DID with Standard IPW"
		drdid_sipw , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
		display "NOT DRDID: DID with Standard IPW with RA"
		drdid_sipwra , touse(`touse') tmt(`tmt') trt(`trt') y(`y') xvar(`xvar') `isily' ivar(`ivar') tag(`tag')
	}
	
	ereturn local cmd drdid
	ereturn local cmdline drdid `00'

end

 
program define drdid_tipw, eclass
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
	** PS
	if "`ivar'"!="" {
	    *display "Estimating IPW logit"
		qui {		
			`isily' logit `trt' `xvar' if `touse'
			tempvar psxb
			predict double `psxb', xb
			tempname psb psV
			matrix `psb'=e(b)
			matrix `psV'=e(V)
			** _delta
			capture drop __dy__
			bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse'
			** Reg for outcome 
		}
		*display "Estimating Counterfactual Outcome"	
		qui {
			*`isily' reg __dy__ `xvar' if `trt'==0 
			*tempname regb regV
			*matrix `regb'=e(b)
			*matrix `regV'=e(V)
			tempvar xb
			*predict double `xb'
			capture drop __att__
			gen double __att__=.
		}
		*display "Estimating ATT"
		qui {
		    tempname b V
			mata:drdid_tipw("__dy__","`xvar'","`xb'","`psb'","`psV'","`psxb'","`trt'","`tmt'","`touse'","__att__","`b'","`V'")
			matrix colname `b'=__att__
			matrix colname `V'=__att__
			matrix rowname `V'=__att__
			ereturn post `b' `V'
			local att1    =`=_b[__att__]'
			local attvar1 =`=_se[__att__]'^2
			ereturn scalar att1    =`att1'
			ereturn scalar attvar1 =`attvar1'
			ereturn matrix ipwb `psb'
			ereturn matrix ipwV `psV'
		}
		display "Traditional IPW estimator. Abadie (2005)"
		ereturn display
	}
	else if "`ivar'"=="" {
	    display in red "RC for IPW not implemented yet"
		exit
		}
end

** can be more efficient
**#
program define drdid_dripw, eclass
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
	** PS
	if "`ivar'"!="" {
	    *display "Estimating IPW logit"
		qui {		
			`isily' logit `trt' `xvar' if `touse'
			tempvar psxb
			predict double `psxb', xb
			tempname psb psV
			matrix `psb'=e(b)
			matrix `psV'=e(V)
			** _delta
			capture drop __dy__
			bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse'
			** Reg for outcome 
		}
		*display "Estimating Counterfactual Outcome"	
		qui {
			`isily' reg __dy__ `xvar' if `trt'==0 
			tempname regb regV
			matrix `regb'=e(b)
			matrix `regV'=e(V)
			tempvar xb
			predict double `xb'
			capture drop __att__
			gen double __att__=.
		}
		*display "Estimating ATT"
		qui {
		    tempname b V
			mata:drdid_ipw("__dy__","`xvar'","`xb'","`psb'","`psV'","`psxb'","`trt'","`tmt'","`touse'","__att__","`b'","`V'")
			matrix colname `b'=__att__
			matrix colname `V'=__att__
			matrix rowname `V'=__att__
			ereturn post `b' `V'
			local att1    =`=_b[__att__]'
			local attvar1 =`=_se[__att__]'^2
			ereturn scalar att1    =`att1'
			ereturn scalar attvar1 =`attvar1'
			ereturn matrix ipwb `psb'
			ereturn matrix ipwV `psV'
			ereturn matrix regb `regb'
			ereturn matrix regV `regV'

		}
		display "Double Robust IPW estimator"
		ereturn display
	}
	else if "`ivar'"=="" {
	    display in red "RC for IPW not implemented yet"
		exit
		}
end

program define drdid_reg, eclass
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
** Simple application. But right now without RIF
	if "`ivar'"!="" {
		qui {
			capture drop __dy__
			bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse' 
			`isily' reg __dy__ `xvar' if `trt'==0 
			tempvar xb
			predict double `xb'
			capture drop __att__
			gen double __att__=.
			//////////////////////
			tempname regb regV
			matrix `regb'=e(b)
			matrix `regV'=e(V)
			tempname b V
			mata:drdid_reg("__dy__", "`xvar'", "`xb'" , "`trt'", "`tmt'" , "`touse'","__att__","`b'","`V'") 
	 
			matrix colname `b' = __att__
			matrix colname `V' = __att__
			matrix rowname `V' = __att__
			ereturn post `b' `V'
		}
		display "OR-DID estimator"
		ereturn display
	}	
	else if "`ivar'"=="" {
	    display in red "RC for IPW not implemented yet"
		exit
		}

end

program define drdid_sipw, eclass
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
** Simple application. But right now without RIF
	if "`ivar'"!="" {
	    *display "Estimating IPW logit"
		qui {		
			`isily' logit `trt' `xvar' if `touse'
			tempvar psxb
			predict double `psxb', xb
			tempname psb psV
			matrix `psb'=e(b)
			matrix `psV'=e(V)
			** _delta
			capture drop __dy__
			bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse'
			** Reg for outcome 
		}
		*display "Estimating Counterfactual Outcome"	
		qui {
			*`isily' reg __dy__ `xvar' if `trt'==0 
			*tempname regb regV
			*matrix `regb'=e(b)
			*matrix `regV'=e(V)
			tempvar xb
			*predict double `xb'
			capture drop __att__
			gen double __att__=.
		}
		*display "Estimating ATT"
		qui {
		    tempname b V		
			noisily mata:drdid_sipw("__dy__","`xvar'","`xb'","`psb'","`psV'","`psxb'","`trt'","`tmt'","`touse'","__att__","`b'","`V'")		
			matrix colname `b'=__att__
			matrix colname `V'=__att__
			matrix rowname `V'=__att__
			ereturn post `b' `V'
			local att1    =`=_b[__att__]'
			local attvar1 =`=_se[__att__]'^2
			ereturn scalar att1    =`att1'
			ereturn scalar attvar1 =`attvar1'
			ereturn matrix ipwb `psb'
			ereturn matrix ipwV `psV'
		}
		display "Standard IPW Estimator"
		ereturn display
	}
	
	else if "`ivar'"=="" {
	    display in red "RC for IPW not implemented yet"
		exit
	}
end

// only one without Mata writting. Consider working on it
program define drdid_sipwra, eclass
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
** Simple application. But right now without RIF
	qui {
		capture drop __dy__
		bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse'
		tempvar sy
		sum __dy__ if  `touse'
		local scl = r(mean)
		gen double `sy'= __dy__/`scl'
		
		qui:teffects ipwra (`sy' `xvar') (`trt' `xvar', logit) if `touse' & `tmt'==0 , atet 
		tempname b V aux
		matrix `aux'=e(b)*`scl'
		matrix `b'=`aux'[1,1]
		matrix `aux'=e(V)*`scl'^2
		matrix `V'=`aux'[1,1]
		matrix colname `b' = __att__
		matrix colname `V' = __att__
		matrix rowname `V' = __att__
		ereturn post `b' `V'
	}
		ereturn display	
end
 
** Needs rewritting 
program define drdid_dript, eclass sortpreserve
syntax, touse(str) trt(str) y(str) [xvar(str)] [noisily] [ivar(str)] [tag(str)] tmt(str)
	if "`ivar'"!="" {
	   	*display "Estimating IPT"
		qui {
			`isily' ml model lf drdid_logit (`trt'=`xvar') if `touse' , maximize  robust
			`isily' ml display
			tempname iptb iptV
			matrix `iptb'=e(b)
			matrix `iptV'=e(V)
			tempvar prx
			predictnl double `prx'=logistic(xb())
			** Determine dy and dyhat
			capture drop __dy__
			
			bysort `touse' `ivar' (`tmt'):gen double __dy__=`y'[2]-`y'[1] if `touse'
			
			** determine weights
			tempvar w1 w0
			gen double `w1' = `trt'
			gen double `w0' = ((`prx'*(1-`trt')))/(1-`prx')
			
			sum `w1' if `touse', meanonly
			replace `w1'=`w1'/r(mean)
			sum `w0' if `touse', meanonly
			replace `w0'=`w0'/r(mean)
			
			** estimating dy_hat for a counterfactual
		}
		*display "Estimating Counterfactual Outcome"	
		qui {	
			tempname regb regV
			`isily' reg __dy__ `xvar' [w=`w0'] if `trt'==0 ,
			matrix `regb' =e(b)
			matrix `regV' =e(V)
			tempvar dyhat
			qui:predict double `dyhat'
			tempvar att
			qui:gen double `att'=__dy__-`dyhat'
			capture drop __att__
			sum `att' if `touse' & `trt'==1, meanonly
			gen double __att__ = r(mean)+  (`w1'-`w0')*`att'-`w1'*r(mean) if `tag'==1  & `touse'
		}
		*display "Estimating ATT"
		tempvar touse2
		qui:gen byte `touse2'=`touse'*(`tag'==1)
		*qui:reg __att__ if   `touse', noheader
		tempname b V
		mata:b_V("`b'","`V'","__att__","`touse2'")
		matrix colname `b'=__att__
		matrix colname `V'=__att__
		matrix rowname `V'=__att__
		ereturn post `b' `V'
		*** Wrapping all
		ereturn local method drdid_ipt
 		ereturn scalar att    =`=_b[__att__]'
		ereturn scalar attvar =`=_se[__att__]'^2
		ereturn matrix iptb `iptb'
		ereturn matrix iptV `iptV'
		ereturn matrix regb `regb'
		ereturn matrix regV `regV'
		display "Improved DR Inverse Tilting estimator"
		ereturn display
	}
	else {
	**# for Crossection estimator    
	    *** if no ivar means its RC.
		*display "Estimating IPT"
		qui {
			`isily' ml model lf drdid_logit (`trt'=`xvar') if `touse' , maximize  robust
			`isily' ml display
			tempname iptb iptV
			matrix `iptb'=e(b)
			matrix `iptV'=e(V)
			tempvar prx
			predictnl double `prx'=logistic(xb())
			** outcomes
			tempvar w1 w0
			gen double `w1' =    `trt'
			gen double `w0' = (1-`trt')*`prx'/(1-`prx')
		}
		*display "Estimating Counterfactual Outcome"	
		qui {
		    tempname regb00 regV00 regb01 regV01 regb10 regV10 regb11 regV11
			tempvar y01 y00 y10 y11
			`isily' reg `y' `xvar' [w=`w0'] if `trt'==0 & `tmt'==0,
			predict double `y00'
			matrix `regb00' =e(b)
			matrix `regV00' =e(V)
			`isily' reg `y' `xvar' [w=`w0'] if `trt'==0 & `tmt'==1,
			predict double `y01'
			matrix `regb01' =e(b)
			matrix `regV01' =e(V)
			tempvar y0
			gen double `y0'=`y00'*(`tmt'==0)+`y01'*(`tmt'==1)
			`isily' reg `y' `xvar'  		   if `trt'==1 & `tmt'==0,
			predict double `y10'
			matrix `regb10' =e(b)
			matrix `regV10' =e(V)
			`isily' reg `y' `xvar'  		   if `trt'==1 & `tmt'==1,
			predict double `y11'
			matrix `regb11' =e(b)
			matrix `regV11' =e(V)
			
			tempvar ww1 ww0 ww11 ww10 ww01 ww00 www0 
			gen double `ww10' = `w1'*(`tmt'==0)
			gen double `ww11' = `w1'*(`tmt'==1)
			gen double `ww00' = `w0'*(`tmt'==0)
			gen double `ww01' = `w0'*(`tmt'==1)
			gen double `www0'=`trt'			
			** Normalizing weights
			foreach i in `ww10' `ww11' `ww00' `ww01' `www0' {
				sum `i' if `touse', meanonly
				replace `i'=`i'/r(mean)
			}
			** estimating ATT
			capture drop __att1__ __att2__ 
			tempvar att1 att2
			gen double `att1'=(`y'-`y0')*(`ww11'-`ww10'-(`ww01'-`ww00'))
			sum `att1' if `touse' 
			gen double __att1__=r(mean) if `touse'
			gen double `att2'=__att1__+ ///
							   ((`www0'-`ww11')*(`y11'-`y01'))- ///
							   ((`www0'-`ww10')*(`y10'-`y00'))
			** then att2				   
			sum `att2' if `touse'
			gen double __att2__=r(mean) if `touse'
			** estimating IFS
			tempvar rif1 rif2
			gen double `rif1'=.
			gen double `rif2'=.
			mata:rif_drdid("`y' `y00' `y01' `y10' `y11'", ///
							"`ww00' `ww01' `ww10' `ww11' `www0'", ///
							"`trt'","`tmt'","`touse'","`rif1'","`rif2'")
			replace __att1__=__att1__+`rif1'
			replace __att2__=__att2__+`rif2'
		}
		tempname b V
		/*display "ATT RC1 estimator"
		mata:b_V("`b'","`V'","__att1__","`touse2'")
		matrix colname `b'=__att__
		matrix colname `V'=__att__
		matrix rowname `V'=__att__
		ereturn post `b' `V'
		ereturn display
		local att1    =`=_b[__att__]'
		local attvar1 =`=_se[__att__]'^2*/
		display "Improved DR Inverse Tilting estimator for RC"
		mata:b_V("`b'","`V'","__att2__","`touse'")
		matrix colname `b'=__att__
		matrix colname `V'=__att__
		matrix rowname `V'=__att__
		ereturn post `b' `V'
		ereturn display
		local att1    =`=_b[__att__]'
		local attvar1 =`=_se[__att__]'^2
		
*** All ereturn stuff

		*ereturn scalar att1    =`att1'
		*ereturn scalar attvar1 =`attvar1'
		ereturn scalar att2    =`att1'
		ereturn scalar attvar2 =`attvar1'
		
		ereturn matrix iptb `iptb'
		ereturn matrix iptV `iptV'
		ereturn matrix regb00 `regb00'
		ereturn matrix regV00 `regV00'
		ereturn matrix regb01 `regb01'
		ereturn matrix regV01 `regV01'
		ereturn matrix regb10 `regb10'
		ereturn matrix regV10 `regV10'
		ereturn matrix regb11 `regb11'
		ereturn matrix regV11 `regV11'
	}
end
 
mata 
	////////////////////////////////////////////////////////////////////////////////////////////////
// SIPW
 
  	void drdid_sipw(string scalar dy_, xvar_, xb_ , psb_,psV_,psxb_,trt_,tmt_,touse,att_,bb,VV) {
	    real matrix dy, xvar, xb, psb, psv, psxb, trt, tmt
 		// Gather all data
		real scalar nn
		dy  =st_data(.,dy_  ,touse)
		nn=rows(dy)
		xvar=st_data(.,xvar_,touse),J(rows(dy),1,1)
		//xb=st_data(.,xb_,touse)
		psxb=st_data(.,psxb_,touse)
		real matrix psc
		psc=logistic(psxb)
		trt =st_data(.,trt_ ,touse)
		tmt =st_data(.,tmt_ ,touse)
		// and matrices
		//psb =st_matrix(psb_ )
		psv =st_matrix(psV_ )
		// for now assume weights = 1
		real scalar w
		w=1
		real matrix w_1, w_0, att_cont, att_treat,
					eta_treat, eta_cont, 
					lin_ps,  att_inf_func
		
	
		w_1= w :* trt
		w_0= w :* psc :* (1 :- trt):/(1 :- psc)
		att_treat = w_1:* dy
		att_cont  = w_0:* dy
		eta_treat = mean(att_treat)/mean(w_1)
		eta_cont  = mean(att_cont)/mean(w_0)
		ipw_att   = eta_treat :- eta_cont
		
		inf_treat = (att_treat :- w_1 :* eta_treat)/mean(w_1)
		inf_cont_1 = (att_cont :- (w_0 :* eta_cont))
		lin_ps = (w:* (trt :- psc) :* xvar)*(psv * nn)
		//M2 =
		inf_cont_2 = lin_ps * mean(w_0 :* (dy :- eta_cont) :* xvar)'
		inf_control = (inf_cont_1 :+ inf_cont_2)/mean(w_0)
		att_inf_func = mean(ipw_att):+inf_treat :- inf_control
 
		st_store(.,att_,touse, att_inf_func)	
		st_matrix(bb,mean(att_inf_func,tmt ))
		st_matrix(VV,variance(att_inf_func,tmt)/sum(tmt))
	}
  
	void drdid_reg(string scalar dy_, xvar_, xb_ , trt_,tmt_,touse,att_,bb,VV) {
	    real matrix dy, xvar, xb, trt, tmt
		// This code is based on Asjad Replication
		// Gather all data
		real scalar nn
		dy  =st_data(.,dy_  ,touse)
		nn=rows(dy)
		xvar=st_data(.,xvar_,touse),J(rows(dy),1,1)
		xb=st_data(.,xb_,touse)
		// psxb=st_data(.,psxb_,touse)
		// real matrix psc
		// psc=logistic(psxb)
		trt =st_data(.,trt_ ,touse)
		tmt =st_data(.,tmt_ ,touse)
		// and matrices
		// psb =st_matrix(psb_ )
		// psv =st_matrix(psV_ )
		// for now assume weights = 1
		real scalar w
		w=1
		real matrix w_1, w_0, att_cont, att_treat,
					eta_treat, eta_cont, wols_x, wols_eX,
					lin_ols, att_inf_func
		
		w_1 = w :* trt
		w_0 = w :* trt
		att_treat = w_1:* dy
		att_cont  = w_0:* xb
		eta_treat = mean(att_treat):/mean(w_1)
		eta_cont  = mean(att_cont)  :/mean(w_0)
		reg_att = eta_treat :- eta_cont
		wols    = w :* (1 :- trt)
		wols_x  = wols :* xvar
		wols_eX = wols :* (dy:-xb) :* xvar
		
		XpX_inv = invsym(quadcross(wols_x, xvar))*nn
		lin_ols = wols_eX * XpX_inv
		inf_treat    = (att_treat :- w_1 * eta_treat):/mean(w_1)
		inf_cont_1   = (att_cont :- w_0 * eta_cont)
		inf_cont_2   = lin_ols * mean(w_0 :* xvar )'
		inf_control  = (inf_cont_1 :+ inf_cont_2):/mean(w_0)
		att_inf_func = mean(reg_att):+(inf_treat :- inf_control)
			
		st_store(.,att_,touse, att_inf_func)	
		st_matrix(bb,mean(att_inf_func,tmt ))
		st_matrix(VV,variance(att_inf_func,tmt)/sum(tmt))
	}
	
 
/////////////////////////////////////////////////////////////////////////////////////////////////	
// TIPW
 	void drdid_tipw(string scalar dy_, xvar_, xb_ , psb_,psV_,psxb_,trt_,tmt_,touse,att_,bb,VV) {
	    real matrix dy, xvar, xb, psb, psv, psxb, trt, tmt
 		// Gather all data
		real scalar nn
		dy  =st_data(.,dy_  ,touse)
		nn=rows(dy)
		xvar=st_data(.,xvar_,touse),J(rows(dy),1,1)
		//xb=st_data(.,xb_,touse)
		psxb=st_data(.,psxb_,touse)
		real matrix psc
		psc=logistic(psxb)
		trt =st_data(.,trt_ ,touse)
		tmt =st_data(.,tmt_ ,touse)
		// and matrices
		psb =st_matrix(psb_ )
		psv =st_matrix(psV_ )
		// for now assume weights = 1
		real scalar w
		w=1
		real matrix w_1, w_0, att_cont, att_treat,
					eta_treat, eta_cont, ipw_att,
					lin_ps, att_lin1, mom_logit, att_lin2, att_inf_func
					
		w_1= w :* trt
		w_0= w :* psc :* (1 :- trt):/(1 :- psc)
		att_treat = w_1:* dy
		att_cont  = w_0:* dy
		eta_treat = mean(att_treat)/mean(w_1)
		eta_cont  = mean(att_cont)/mean(w_1)
		ipw_att   = eta_treat - eta_cont
		lin_ps = (w:* (trt :- psc) :* xvar)*(psv * nn)
		att_lin1  = att_treat :- att_cont
		mom_logit = mean(att_cont  :* xvar)
		att_lin2  = lin_ps * mom_logit'
		att_inf_func = mean(ipw_att):+(att_lin1 :- att_lin2 :- w_1 :* ipw_att)/mean(w_1)
		mean(att_inf_func)
		sqrt(variance(att_inf_func)/nn)
		st_store(.,att_,touse, att_inf_func)	
		st_matrix(bb,mean(att_inf_func,tmt ))
		st_matrix(VV,variance(att_inf_func,tmt)/sum(tmt))
	}
	
 	void drdid_ipw(string scalar dy_, xvar_, xb_ , psb_,psV_,psxb_,trt_,tmt_,touse,att_,bb,VV) {
	    real matrix dy, xvar, xb, psb, psv, psxb, trt, tmt
		// This code is based on Asjad Replication
		// Gather all data
		real scalar nn
		dy  =st_data(.,dy_  ,touse)
		nn=rows(dy)
		xvar=st_data(.,xvar_,touse),J(rows(dy),1,1)
		xb=st_data(.,xb_,touse)
		psxb=st_data(.,psxb_,touse)
		real matrix psc
		psc=logistic(psxb)
		trt =st_data(.,trt_ ,touse)
		tmt =st_data(.,tmt_ ,touse)
		// and matrices
		psb =st_matrix(psb_ )
		psv =st_matrix(psV_ )
		// for now assume weights = 1
		real scalar w
		w=1
		
		// TRAD DRDID
		real matrix w_1, w_0 
		w_1 = (w:*trt)
		w_1 = w_1 /mean(w_1)
		w_0 = (w:*psc:*(-trt:+1):/(-psc:+1))
		w_0 = w_0 /mean(w_0 ) 
		// ATT
		real matrix dy_xb, att, w_ols, wols_eX,
					XpX_inv, lin_wols, lin_ps, 
					n1, n0, nest, a, rif
					
		dy_xb=dy:-xb
		att = mean((w_1:-w_0):*(dy_xb))
		
		// influence functions OLS
		w_ols 	 =    w :* (1 :- trt)
		wols_eX  = w_ols:* (dy_xb):* xvar
		XpX_inv  = invsym(quadcross(xvar,w_ols,xvar))*nn 
		lin_wols =  wols_eX * XpX_inv   
		// IF for logit
		//# Asymptotic linear representation of logit's beta's
		// w placeholder for weights
		lin_ps 	   = (w :* (trt:-psc) :* xvar) * (psv * nn)
		// Components for RIF
		n1   = w_1:*((dy_xb):-mean(dy_xb,w_1))
		n0   = w_0:*((dy_xb):-mean(dy_xb,w_0))
		
		a    = ((1:-trt):/(1:-psc):^2)/ mean(psc:*(1:-trt):/(1:-psc))
		// This only works because w_1 and w_0 are mutually exclusive
		nest = lin_wols * (mean(xvar,w_1):-mean(xvar,w_0))' :+
		       lin_ps   * mean( a :* (dy_xb :- mean(dy_xb,w_0)) :* exp(psxb):/(1:+exp(psxb)):^2:*xvar)'			   
		// RIF att_inf_func = inf_treat' :- inf_control
		rif = att:+n1:-n0:-nest
		st_store(.,att_,touse, rif)	
		st_matrix(bb,mean(rif,tmt))
		st_matrix(VV,variance(rif,tmt)/sum(tmt))
	}
	// need to modify code to get better estimates. Right now constrain to tmt=1. (time fix. But ideally, should be done average?)
	// same with DRipt. Option. when using DR use cluster??
	
	void b_V (string scalar b,v,att,touse) {
	    real matrix att2
	    st_view(att2=.,.,att,touse)
		st_matrix(b,mean(att2))
		st_matrix(v,variance(att2)/rows(att2))
	}
 	
	void rif_drdid(string scalar y, w , tr, tm, touse, nv1, nv2){
		real matrix yy,ww,trt,tmt
		yy =st_data(., y,touse)
		ww =st_data(., w,touse)
		trt=st_data(.,tr,touse)
		tmt=st_data(.,tm,touse)
		//now i need vectors for YY's WW's etc
		//mata:rif_drdid
		// ("`y'    `y00' `y01'  `y10'  `y11'"
		//  yy[,1] yy[,2] yy[,3] yy[,4] yy[,5]
		//"`ww00' `ww01' `ww10' `ww11' `www0'"
		//,"`trt'","`tmt'","`touse'")
		//   w00    w01      w10    w11
		// ww[,1]  ww[,2]	ww[,3] ww[,4]
		real matrix n111, n110, n101, n100, n1
		real matrix n211, n210, n21, n2
		n111=ww[,4]:*((yy[,1]:-yy[,3]):-mean(yy[,1]:-yy[,3],ww[,4]))
		n110=ww[,3]:*((yy[,1]:-yy[,2]):-mean(yy[,1]:-yy[,2],ww[,3]))
		n101=ww[,2]:*((yy[,1]:-yy[,3]):-mean(yy[,1]:-yy[,3],ww[,2]))
		n100=ww[,1]:*((yy[,1]:-yy[,2]):-mean(yy[,1]:-yy[,2],ww[,1]))
		//n11=n111:-n110
		//n10=n101:-n100
		n1=(n111:-n110):-(n101:-n100)
		
		n211=ww[,5]:*((yy[,5]:-yy[,4]):-mean(yy[,5]:-yy[,4],ww[,5])):+
			(ww[,4]:*((yy[,1]:-yy[,5]):-mean(yy[,1]:-yy[,5],ww[,4])))
		n210=ww[,5]:*((yy[,3]:-yy[,2]):-mean(yy[,3]:-yy[,2],ww[,5])):+
			(ww[,3]:*((yy[,1]:-yy[,4]):-mean(yy[,1]:-yy[,4],ww[,3])))
		n21=n211:-n210
		n2=n21:-(n101:-n100)
		//n20=n10
		st_store(.,nv1,touse,n1)
		st_store(.,nv2,touse,n2)

	}


end


** estimators left
**dp p
** dr p imp Done
** reg perhaps via teffects
**ipw p perhaps via gmm and manual
** ipw p std via teffects 
