# Gen-Transmission Maintenance Scheduling Models with LR
# Author: Xingpeng Li, https://rpglab.github.io/

set BUS;    # set of buses
set BRANCH; # set of branches
set GEND;   # Gen Data

#### PARAMETERS:
# Bus Data
param bus_num		{BUS}; # Bus Number
param bus_Pd		{BUS}; # Real Power Demand 

# GENData
param genD_num		{GEND}; # index of generator
param genD_bus		{GEND}; # GEN location
param genD_minUP	{GEND}; # Min UP Time
param genD_minDN	{GEND}; # Min Down Time
param genD_Init_Stat	{GEND}; # Initial UC Variable (1 for on)
param genD_Init_Pg	{GEND}; # Initial power output
param genD_Init_t	{GEND}; # Initial periods that is already on(positive num) or off(negative num).
param genD_Pmax		{GEND}; # Max gen production
param genD_Pmin     {GEND}; # Min gen production when committed
param genC_Startup 	{GEND}; # startup cost
param genC_Cost		{GEND}; # Linear Cost Term
param genC_NLoad	{GEND}; # No Load Cost
param SPRamp		{GEND}; # 10 Min Spin Ramp
param HRamp		{GEND}; # Hourly Ramp
param StartRamp		{GEND}; # Startup/Shutdown Ramp
param genM_mark     {GEND}; # 1 donotes this generator needs maintenance.
param genM_cost     {GEND};
param genM_MTg     {GEND};   # time periods needed for the maintenance.
param genM_startingT     {GEND};   # Starting time of this generator maintenance window.
param genM_endingT     {GEND};   # Ending time of this generator maintenance window.

# Branch Data
param branch_num    {BRANCH}; # index of branch
param branch_fbus	{BRANCH}; # from bus for line
param branch_tbus	{BRANCH}; # to bus for line
param branch_x		{BRANCH}; # line reactance
param branch_rateA	{BRANCH}; # long term thermal rating
param branch_rateC	{BRANCH}; # emergency thermal rating
param branch_radial		{BRANCH}; # whether you will monitor the line
param branchM_mark   {BRANCH};  # 1 donotes this branch needs maintenance.
param branchM_cost   {BRANCH};
param branchM_MTk   {BRANCH};  # time periods needed for the maintenance.
param branchM_startingT     {BRANCH};   # Starting time of this generator maintenance window.
param branchM_endingT     {BRANCH};   # Ending time of this generator maintenance window.


set Nk = {j in BRANCH: branch_radial[j] == 0};
set Ng = GEND;

# Load Data
param nT; let nT := 168;  # time-frame of outage coordination
param nTofI; let nTofI := 24;  # number of periods in an interval
param numI;    # number of intervals
set LOAD = {1..nT};   # Load Percent data of peak load
set LOAD_UC = {1..nTofI};   # Load Percent data of peak load
set LOAD24;
param load_pcnt	 {LOAD24}; # the percentage of annual peak
param Bus_Pd {n in BUS, t in LOAD};  # Creates the hourly load per bus
param Bus_Pd_UC {n in BUS, t in LOAD_UC};  # Creates the hourly load per bus
param MBase; let MBase:=100; # the MVA Base

# Additional Parameters that are not loaded through sets:
param dual_YktJkt {j in BRANCH, t in LOAD};  # the dual (corresponding to J) that needs updated
param dual_XgtUgt {g in GEND, t in LOAD};  # the dual (corresponding to U) that needs updated
param dual_XgtUgt_tmp {g in GEND, t in LOAD};  # the dual (corresponding to U) that needs updated
param dual_YktJkt_UC {j in BRANCH, t in LOAD};  # the dual (corresponding to J) that needs updated
param dual_XgtUgt_UC {g in GEND, t in LOAD};  # the dual (corresponding to U) that needs updated

param fixed_YktJkt_UC {j in BRANCH, t in LOAD_UC};
param fixed_XgtUgt_UC {g in GEND, t in LOAD_UC};

param penalty; let penalty := 10^9;

param nCUT;
param BigM; let BigM := 1e6;
param Jopen; let Jopen := 0;
param nMainteT; let nMainteT := 0;
param nMainteG; let nMainteG := 0;

#### VARIABLES:
#var obj_M;
var Xgt {g in GEND, t in LOAD} binary;      # Maintenance status of unit g at time t. 
var agt {g in GEND, t in LOAD} binary;      #  
var bgt {g in GEND, t in LOAD} binary;      # 
var Ykt {k in BRANCH, t in LOAD} binary;      # Maintenance status of transmission line k at time t. 
var ckt {k in BRANCH, t in LOAD} binary;      #  
var dkt {k in BRANCH, t in LOAD} binary;      #  

var Jkt {k in BRANCH, t in LOAD_UC} binary;      #  status of transmission
var Ugt {g in GEND, t in LOAD_UC} binary; # unit commitment var
var Vgt {g in GEND, t in LOAD_UC} >= 0, <=1; # startup var (binary var modeled as continuous since it will have binary solution)
var gen_supply {g in GEND, t in LOAD_UC};      # Variable for GEN Supply
var reserve {g in GEND, t in LOAD_UC} >= 0;
var line_flow {j in BRANCH, t in LOAD_UC};     # Variable for all line flows
var bus_angle {n in BUS, t in LOAD_UC};        # Variable for Bus Angles
var LdSheding1 {n in BUS, t in LOAD_UC} >=0;

param best_Xgt {g in GEND, t in LOAD} ;      # Maintenance status of unit g at time t. 
param best_Ykt {k in BRANCH, t in LOAD} ;      # Maintenance status of transmission line k at time t. 
param best_Jkt {k in BRANCH, t in LOAD} ;      #  
param best_Ugt {g in GEND, t in LOAD} ; # unit commitment var
param best_Vgt {g in GEND, t in LOAD} >= 0, <=1; # startup var (binary var modeled as continuous since it will have binary solution)
param best_gen_supply {g in GEND, t in LOAD};      # Variable for GEN Supply
param best_reserve {g in GEND, t in LOAD} >= 0;
param best_line_flow {j in BRANCH, t in LOAD};     # Variable for all line flows
param best_bus_angle {n in BUS, t in LOAD};        # Variable for Bus Angles

param temp_Ykt {j in BRANCH, t in LOAD} binary;
param temp_Jkt {j in BRANCH, t in LOAD} binary;
param temp_Xgt {g in GEND, t in LOAD} binary;
param temp_Ugt {g in GEND, t in LOAD} binary;
param temp_Vgt {g in GEND, t in LOAD} binary;
param temp_gen_supply {g in GEND, t in LOAD};
param temp_reserve {g in GEND, t in LOAD};
param temp_line_flow {j in BRANCH, t in LOAD};
param temp_bus_angle {n in BUS, t in LOAD};

param tempUB_Jkt {j in BRANCH, t in LOAD} ;
param tempUB_Ugt {g in GEND, t in LOAD} ;
param tempUB_Vgt {g in GEND, t in LOAD} >= 0, <=1;
param tempUB_gen_supply {g in GEND, t in LOAD};
param tempUB_reserve {g in GEND, t in LOAD};
param tempUB_line_flow {j in BRANCH, t in LOAD};
param tempUB_bus_angle {n in BUS, t in LOAD};



#### OBJECTIVE: Minimize Cost
minimize M_COST_S1_UC: sum{g in GEND, t in LOAD_UC}(gen_supply[g,t]*MBase*genC_Cost[g]+Ugt[g,t]*genC_NLoad[g]+Vgt[g,t]*genC_Startup[g])
                    + sum{j in BRANCH, t in LOAD_UC}dual_YktJkt_UC[j,t]*Jkt[j,t]
                    + sum{g in GEND, t in LOAD_UC}dual_XgtUgt_UC[g,t]*Ugt[g,t]; 
           
minimize M_COST_S1_UC_fixed: sum{g in GEND, t in LOAD_UC}(gen_supply[g,t]*MBase*genC_Cost[g]+Ugt[g,t]*genC_NLoad[g]+Vgt[g,t]*genC_Startup[g]) 
				 + penalty*sum{n in BUS, t in LOAD_UC}(LdSheding1[n,t]);

minimize M_COST_S2: sum{j in BRANCH, t in LOAD}-dual_YktJkt[j,t]*Ykt[j,t];

minimize M_COST_S3: sum{g in GEND, t in LOAD}-dual_XgtUgt[g,t]*Xgt[g,t];

### Maintenance constraints for transmission
subject to MC_Transm1{k in BRANCH, t in LOAD: t>=2}: 
    ckt[k,t] - dkt[k,t] = Ykt[k,t-1] - Ykt[k,t];

subject to MC_Transm2{k in BRANCH}: 
    ckt[k,1] - dkt[k,1] = 1 - Ykt[k,1];

subject to MC_Transm3{k in BRANCH, t in LOAD}: 
    ckt[k,t] + dkt[k,t] <= 1;
	
subject to MC_Transm4{k in BRANCH: branchM_mark[k] == 1}: 
    sum{t in LOAD: branchM_startingT[k]<=t<=branchM_endingT[k]}(1-Ykt[k,t]) = branchM_MTk[k];
	
subject to MC_Transm5{k in BRANCH: branchM_mark[k] == 1}: 
    sum{t in LOAD: branchM_startingT[k]<=t<=branchM_endingT[k]}ckt[k,t] = 1;
	
#subject to MC_Transm5_test{k in BRANCH: branchM_mark[k] == 1}: 
#    sum{t in LOAD: branchM_startingT[k]+1<=t<=branchM_endingT[k]+1}dkt[k,t] = 1;
	
subject to MC_Transm6{k in BRANCH, t in LOAD: t<branchM_startingT[k] || t>branchM_endingT[k]}: 
    Ykt[k,t] = 1;

subject to MC_Transm7{k in BRANCH, t in LOAD: branchM_mark[k] == 0}:
    Ykt[k,t] = 1;

### Maintenance constraints for generators
subject to MC_Gen1{g in GEND, t in LOAD: t>=2}: 
    agt[g,t] - bgt[g,t] = Xgt[g,t-1] - Xgt[g,t];

subject to MC_Gen2{g in GEND}: 
    agt[g,1] - bgt[g,1] = 1 - Xgt[g,1];
	
subject to MC_Gen3{g in GEND, t in LOAD}: 
    agt[g,t] + bgt[g,t] <= 1;
	
subject to MC_Gen4{g in GEND: genM_mark[g] == 1}: 
    sum{t in LOAD: genM_startingT[g]<=t<=genM_endingT[g]}(1-Xgt[g,t]) = genM_MTg[g];
	
subject to MC_Gen5{g in GEND: genM_mark[g] == 1}: 
    sum{t in LOAD: genM_startingT[g]<=t<=genM_endingT[g]}agt[g,t] = 1;
	
#subject to MC_Gen5_test{g in GEND: genM_mark[g] == 1}: 
#    sum{t in LOAD: genM_startingT[g]+1<=t<=genM_endingT[g]+1}bgt[g,t] = 1;
	
subject to MC_Gen6{g in GEND, t in LOAD: t<genM_startingT[g] || t>genM_endingT[g]}: 
    Xgt[g,t] = 1;

subject to MC_Gen7{g in GEND, t in LOAD : genM_mark[g] == 0}:
    Xgt[g,t] = 1;
	
### Bundling Constraints
#subject to BundlingC2{k in BRANCH, t in LOAD}:
#    Jkt[k,t] = Ykt[k,t];

### Base case modeling of generation:
subject to PGen1{g in GEND, t in LOAD_UC}: # Gen min constraint for steady-state
	genD_Pmin[g]*Ugt[g,t] <= gen_supply[g,t];

subject to unitReserve2{g in GEND, t in LOAD_UC}:
	gen_supply[g,t] + reserve[g,t] <= genD_Pmax[g]*Ugt[g,t];

subject to unitReserve1{g in GEND, t in LOAD_UC}: 
	reserve[g,t] <= SPRamp[g]*Ugt[g,t];

subject to systemReserve{g in GEND, t in LOAD_UC}:
	sum{s in GEND}reserve[s,t] >= gen_supply[g,t] + reserve[g,t];

#	Ramping constraints
subject to HR_RampUP{g in GEND, t in LOAD_UC: t>=2}:
	gen_supply[g,t]-gen_supply[g,t-1] <= HRamp[g]*Ugt[g,t-1] + StartRamp[g]*Vgt[g,t];
	
subj to HR_RampUP2{g in GEND}:
	gen_supply[g,1] <= StartRamp[g]*Vgt[g,1];
	
subject to HR_RampDN{g in GEND, t in LOAD_UC: t>=2}:
	gen_supply[g,t-1]-gen_supply[g,t] <= HRamp[g]*Ugt[g,t] + StartRamp[g]*(Vgt[g,t]-Ugt[g,t]+Ugt[g,t-1]);

# Min up time constraint:
subj to FacetUP{g in GEND, t in LOAD_UC: t>=genD_minUP[g] }:
	sum{m in LOAD_UC: t-genD_minUP[g]+1<=m<=t}Vgt[g,m] <= Ugt[g,t];

# Min down time constraint:
subj to FacetDN{g in GEND, t in LOAD_UC: t<=nT-genD_minDN[g]}:
	sum{m in LOAD_UC: t+1<=m<=t+genD_minDN[g]}Vgt[g,m] <= 1-Ugt[g,t];

subject to SUSD{g in GEND, t in LOAD_UC: t>=2}:
	Vgt[g,t] >= Ugt[g,t] - Ugt[g,t-1];

subject to SUSD2{g in GEND}:
	Vgt[g,1] >= Ugt[g,1] - 0;

### Base case modeling of power flow:
subject to PowerBal{k in BUS, t in LOAD_UC}: # Node Balance Constraint, steady-state
	sum{j in BRANCH: branch_tbus[j] ==k}line_flow[j,t]                 #flows into bus
	- sum{j in BRANCH: branch_fbus[j]==k}line_flow[j,t]                # flows out of bus
	+ sum{g in GEND: genD_bus[g]==k}gen_supply[g,t] - Bus_Pd_UC[k,t] = 0;  # supply and load at bus


subject to PowerBal_LS{k in BUS, t in LOAD_UC}: # Node Balance Constraint, steady-state
	sum{j in BRANCH: branch_tbus[j] ==k}line_flow[j,t]              #flows into bus
	- sum{j in BRANCH: branch_fbus[j]==k}line_flow[j,t]              # flows out of bus
	+ sum{g in GEND: genD_bus[g]==k}gen_supply[g,t] - Bus_Pd_UC[k,t]   # supply and load at bus
	+ LdSheding1[k,t] = 0;                           # load shedding at bus

subject to LdSheddingCons{k in BUS, t in LOAD_UC}: LdSheding1[k,t] <= Bus_Pd_UC[k,t];
	
subject to Thermal1{j in BRANCH, t in LOAD_UC}:		# Thermal Constraint, steady-state
	line_flow[j,t] <= branch_rateA[j]*Jkt[j,t]; # based on Rate A

subject to Thermal2{j in BRANCH, t in LOAD_UC}:		# Thermal Constraint 2, steady-state
	-branch_rateA[j]*Jkt[j,t] <= line_flow[j,t]; #based on Rate A

subject to Line_FlowEq{j in BRANCH, t in LOAD_UC}:	#Line Flow Constraint for steady-state:
	line_flow[j,t] - (bus_angle[branch_fbus[j],t]-bus_angle[branch_tbus[j],t])/branch_x[j] <= BigM*(1-Jkt[j,t]);

subject to Line_FlowEq2{j in BRANCH, t in LOAD_UC}:	#Line Flow Constraint for steady-state:
	line_flow[j,t] - (bus_angle[branch_fbus[j],t]-bus_angle[branch_tbus[j],t])/branch_x[j] >= -BigM*(1-Jkt[j,t]);
	
subject to Jkt_Tighten1{k in BRANCH, t in LOAD_UC: branchM_mark[k] == 0}:
    Jkt[k,t] = 1;

subject to Jkt_Tighten2{k in BRANCH, t in LOAD_UC: t<branchM_startingT[k] || t>branchM_endingT[k]}: 
    Jkt[k,t] = 1;

subject to Jkt_Tighten3{k in BRANCH: branchM_mark[k] == 1}:
    sum{t in LOAD_UC}(1-Jkt[k,t]) <= branchM_MTk[k];

subject to Jkt_Fixed{j in BRANCH, t in LOAD_UC}:
    Jkt[j,t] = fixed_YktJkt_UC[j,t];

subject to Ugt_Fixed{g in GEND, t in LOAD_UC}:
    Ugt[g,t] <= fixed_XgtUgt_UC[g,t];
