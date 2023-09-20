function par = getPar()

% Function defining model parameter values
%
% USAGE: par = getPar()
%
% OUTPUTS: par - a structure containing parameter values


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters for renewal equation particle filter
par.nParticles = 1e5;                    % Number of particles, 1e5 for final results
par.sigmaR = 0.025;                      % S.D. in daily random walk step for Rt
par.overdispFactorCases = 100;           % NegBin overdispersion factor for observed daily cases
par.overdispFactorHosp = 100;            % NegBin overdispersion factor for new daily admissions
par.nDaysDOW = 15*7;                     % Maximum number of days over which to fit the day-of-the week effects
par.tBurnIn = 20;                        % Burn in period
par.qt = 0.05:0.05:0.95;                 % quantiles for saving outputs
par.forecastPeriod = 21;                 % Forecast period subsequent to readDate


% Gen time dist
aMax = 14;
genA = 3.7016; genB = 2.826;
C = wblcdf(0:aMax, genA, genB);
par.GT = diff(C);
par.GT = par.GT/sum(par.GT);

% Incubation period 
incubA = 3.6;  incubB = 1.5;
C = wblcdf(0:aMax, incubA, incubB);
par.incub = diff(C);
par.incub = par.incub/sum(par.incub);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters for hospitalisation risk model

% Time windows for fitting model for age distirbution of cases and p(hosp):
par.ageSplitModel_wStart = 28;       % (56) Days before latest data to start age split model
par.ageSplitModel_wEnd = 0;          % Days before latest data to end age split model
par.hospModel_wStart = 84;           % Days before latest data to start hosp risk model
par.hospModel_wEnd = 21;             % Days before latest data to end hosp risk model

% Mode for fitting probability of hospitalisation (CHR) model 
% Set to either "national" or "local"
% "national" uses national data to estimate the age-dependent CHR and takes its variability through time within the fitting window
% "local" use data from the specified forecast area, but in situations where the fitted response variable is zero on some days (due to small numbers of hospital admissions) will just fit a single time-invariant estimate for CHR with a binomial confidence interval. This may understate uncertainty in CHR.
par.hospModelMode = "national";     

% Kernel functions for GPR models
par.caseModelKernelFn = 'squaredexponential';
par.hospModelKernelFn = 'squaredexponential';

par.hospOccSDWindow = 14;            % Time window for calculating SD in recent hospital occupancy

par.refAge = 5;                      % reference age group for ratios 




