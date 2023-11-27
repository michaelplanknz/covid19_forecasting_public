function [Rt, It, Zt, Ct, LL, ESS] = runPF(t, epiData, ItoR_array, ItoR_relFreq, par)

% Function to run the particle filter on given input data
%
% USAGE: [Rt, It, Zt, Ct, LL] = runPF(t, epiData, ItoR_array, ItoR_relFreq, par)
%
% INPUTS: t - vector of daily dates defining the model simulation period
%         epiData - table of epi data
%         ItoR_array - array of infection to report times (days)
%         ItoR_relFreq - relative frequence (probability mass) of those infection to report times
%         par - structure of model parameters
%
% OUTPUTS: Rt - matrix of reproduction numbers - (i,j) element corresponds to particle i on day j
%          It - matrix of daily infections  - (i,j) element corresponds to particle i on day j
%          Zt - matrix of infections by assigned date of report (independent of whether they actually reported as a case or not)  - (i,j) element corresponds to particle i on day j
%          Ct - matrix of daily cases  - (i,j) element corresponds to particle i on day j
%          LL - vector of log lilelihoods for each particle

nSteps = length(t);


% Fit day of the week effect:
DOW_effect = findDOW_effect(epiData, par.nDaysDOW);




% Initialise variables for renewal equation particle filter
Rt = zeros(par.nParticles, nSteps);
It = zeros(par.nParticles, nSteps);
Zt = zeros(par.nParticles, nSteps);
LL = zeros(par.nParticles, nSteps);
ESS = par.nParticles*ones(nSteps, 1);
DOWindex = mod(datenum(t), 7)+1;

% Initialise variables during the burn in period
% Initialise cases as Poisson random variables with smoothed data on new
% daily cases as mean. Shift back in time by the mean infectoin to report
% delay to get cases by date of infection (It). 
mean_ItoR = sum(ItoR_array.*ItoR_relFreq);
poissMean = repmat(epiData.nCasesSmoothed(1+round(mean_ItoR):par.tBurnIn+round(mean_ItoR))', par.nParticles, 1);
It(:, 1:par.tBurnIn) = poissrnd(poissMean);

% For the inital value of Rt (needed for first time step), use epiEstim on
% the number of infections during the burn in period and sample from the estimate posterior for Rt on the last day of the burn in period
[~, ~, sh, sc] = epiEstim(It(:, 1:par.tBurnIn), par.GT, 1, 2, 7, 0.05);  
Rt(:, par.tBurnIn) = gamrnd(sh(:, end), sc(:, end));

lastData = epiData.t(find(~isnan(epiData.nCases), 1, 'last' ));

% Loop through time steps
for iStep = par.tBurnIn+1:nSteps
   Rt(:, iStep) = max(0, Rt(:, iStep-1) + par.sigmaR*randn(par.nParticles, 1));                             % random walk step for Rt
   It(:, iStep) = poissrnd(  Rt(:, iStep) .* sum(par.GT.*It(:, iStep-1:-1:iStep-length(par.GT)), 2));       % renewal equation
   Zt(:, iStep) = sum(ItoR_relFreq.*It(:, iStep-1:-1:iStep-length(ItoR_relFreq)), 2);                                   % infections by date of report
        
   % Particle resampling (only during period for which data is available)
   if t(iStep) <= lastData
        weights = nbinpdf(round(epiData.nCases(iStep)), par.overdispFactorCases, par.overdispFactorCases./(DOW_effect(DOWindex(iStep))*Zt(:, iStep)+par.overdispFactorCases));
        LL(:, iStep) = log(weights);
        
        resampInd = randsample(par.nParticles, par.nParticles, true, weights);
        ESS(iStep) = length(unique(resampInd));
        Rt = Rt(resampInd, :);
        It = It(resampInd, :);
        Zt = Zt(resampInd, :);
        LL = LL(resampInd, :);
   end
end

 % Generate samples from the reported case distribution to construct
 % prediction intervals:
Ct = nbinrnd(par.overdispFactorCases, par.overdispFactorCases./(DOW_effect(DOWindex).*Zt+par.overdispFactorCases));     


