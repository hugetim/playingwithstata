## Baker Example
This is an alternative version to Grant McDermott Baker test

```stata
clear
set seed 1234
set obs 1000
gen id = _n
expand 30
bysort id:gen n =_n
bysort id:gen year=_n+1980-1
gen state=1+floor((id-1)/25)
gen firms = runiform(0,5)
gen group =1 +floor((state-1)/10)
gen treat_date = 1980 + group * 6

gen time_til = year-treat_date
gen treat      = time_til>=0
gen e = rnormal(0,0.5^2)
gen te = rnormal(10-2*(group-1),0.2^2)
gen y = firms+ n+treat*te*(year-treat_date+1)+e
gen y2 = firm + n + te*treat + e
```

Then just estimate the model
```
jwdid y, tvar(year) gvar(treat_date) ivar(id)
estat event
```

Which should give you this:
```
---------------------------------------------------------------
              |            Delta-method
              |   Contrast   std. err.     [95% conf. interval]
--------------+------------------------------------------------
_at@__event__ |
 (2 vs 1)  0  |   7.965755    .068828      7.830854    8.100655
 (2 vs 1)  1  |   16.04959   .0716781       15.9091    16.19008
 (2 vs 1)  2  |   24.11867   .0712338      23.97905    24.25828
 (2 vs 1)  3  |   31.97317    .070788      31.83443    32.11192
 (2 vs 1)  4  |   40.05539   .0720049      39.91426    40.19652
 (2 vs 1)  5  |   47.97392   .0733804      47.83009    48.11774
 (2 vs 1)  6  |   62.98808   .0936827      62.80446    63.17169
 (2 vs 1)  7  |   71.98679   .0941246      71.80231    72.17127
 (2 vs 1)  8  |   81.16876   .0951231      80.98232    81.35519
 (2 vs 1)  9  |   90.03304   .0950862      89.84668    90.21941
 (2 vs 1) 10  |   98.94166   .0962399      98.75304    99.13029
 (2 vs 1) 11  |   107.9539   .0960996      107.7655    108.1422
 (2 vs 1) 12  |   129.7566   .1478697      129.4667    130.0464
 (2 vs 1) 13  |    139.977    .144652      139.6935    140.2605
 (2 vs 1) 14  |   149.9825   .1464179      149.6955    150.2694
 (2 vs 1) 15  |   159.9989   .1476829      159.7094    160.2884
 (2 vs 1) 16  |   169.9088   .1426392      169.6292    170.1883
 (2 vs 1) 17  |   179.7438    .149597      179.4506     180.037
---------------------------------------------------------------
```

And of course the real thing


```
use https://github.com/scunning1975/mixtape/raw/master/baker.dta, clear
jwdid y, tvar(year) gvar(treat_date) ivar(id)
estat event
[output ommitted]
---------------------------------------------------------------
              |            Delta-method
              |   Contrast   std. err.     [95% conf. interval]
--------------+------------------------------------------------
_at@__event__ |
 (2 vs 1)  0  |   8.013848   .0120173      7.990295    8.037402
 (2 vs 1)  1  |   16.00015   .0126558      15.97534    16.02495
 (2 vs 1)  2  |   24.00288   .0128225      23.97775    24.02802
 (2 vs 1)  3  |   31.99449   .0135523      31.96793    32.02105
 (2 vs 1)  4  |   39.99836   .0134891      39.97192     40.0248
 (2 vs 1)  5  |   48.01327   .0152663      47.98335    48.04319
 (2 vs 1)  6  |   62.98755   .0196963      62.94894    63.02615
 (2 vs 1)  7  |   71.98894   .0213788      71.94703    72.03084
 (2 vs 1)  8  |   80.97874   .0208447      80.93788    81.01959
 (2 vs 1)  9  |   89.98241   .0234815      89.93638    90.02843
 (2 vs 1) 10  |   99.04746   .0239378      99.00055    99.09438
 (2 vs 1) 11  |   108.0061    .027114       107.953    108.0593
 (2 vs 1) 12  |   129.9179   .0400181      129.8395    129.9963
 (2 vs 1) 13  |   139.9251   .0400635      139.8466    140.0036
 (2 vs 1) 14  |   150.0103   .0413148      149.9293    150.0912
 (2 vs 1) 15  |   159.9718   .0469927      159.8797    160.0639
 (2 vs 1) 16  |   169.9872   .0500673      169.8891    170.0853
 (2 vs 1) 17  |   179.9825   .0528856      179.8789    180.0862
---------------------------------------------------------------

```
