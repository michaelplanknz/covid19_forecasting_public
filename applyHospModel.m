function [At, Dt, Ht, pCasesSamp, pHospSamp, CHR] = applyHospModel(t, It, mdlCase, mdlHosp, fittedFlag, epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, ItoR_array, ItoR_relFreq, par)

% Function to apply the results of the hopsitalisation model to the output of the particle filter to produce daily admissions, discharges and occupancy
%
% USAGE: [At, Dt, Ht, pCasesSamp, pHospSamp, CHR] = applyHospModel(t, It, mdlCase, mdlHosp, epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, ItoR_array, ItoR_relFreq, par)
%
% INPUTS: t - vector of daily dates defining the model simulation period
%         It - matrix daily infections as returned by runPF()
%         mdlCase - fitted GP regression for age distribution of cases as returned by fitCaseDistModel()
%         mdlHosp - fitted GP regression for CHR as returned by fitHospModel()
%         fittedFlag - flag indicating whether a GP regression model has been fitted to each age group as returned by fitHospModel()
%         epiData - table of combined epi and hospital occupancy data
%         ageBreaks - vector of bin edges defining age groups
%         LOS_array - array of Covid-related length of stay values (days)
%         LOS_freq - array of frequencies of those length of stay values in 10-year age groups
%         RtoA_array - array of report to admission values (days)
%         RtoA_freq - array of frequencies of those report to admission values
%         ItoR_array - array of infectoin to report values (days)
%         ItoR_relFreq - array of relative frequencies (probability mass) of those infectoin to report values
%         par - structure of model parameters as returned by getPar()        
%
% OUTPUTS: At - matrix of daily admissions - (i,j) element corresponds to particle i on day j
%          Dt - matrix of daily discharges - (i,j) element corresponds to particle i on day j
%          Ht - matrix of hospital occupancy - (i,j) element corresponds to particle i on day j
%          pCasesSamp - nParticles samples from the fitted GP regression model for the proportion of cases in each age group
%          pHospSamp - nParticles samples from the fitted GP regression model for the CHR in each age group
%          CHR - nParticles samples of the overall CHR across all age groups

nSteps = length(t);
nParticles = size(It, 1);

% Calculate some infection to admission and LOS distributions
RtoA_relFreq = RtoA_freq/sum(RtoA_freq);   % report to admission distributoin (empirical)

ItoA_array = 1+RtoA_array(1):length(ItoR_array)+RtoA_array(end);
ItoA = conv(ItoR_relFreq, RtoA_relFreq);            % inferred infection to admission distribution
ItoA = ItoA(ItoA_array >= 1);              % truncate distribution to >= 1
ItoA_array = ItoA_array(ItoA_array >= 1);
ItoA = ItoA/sum(ItoA);   




LOS_relFreq = LOS_freq./sum(LOS_freq, 2);   % length of stay distribution for each age group (empirical)

% Recent hosp occ data
ind = find(~isnan(epiData.Hosp), 1, 'last' );
tHosp0 = epiData.t(ind);
hospOccLatest = epiData.HospSmoothed(ind);                                 % most recent data for hopsital occupancy - used for intial condition for forecast
hospOccLatestSD = nanstd(epiData.Hosp(ind-par.hospOccSDWindow+1:ind));     % standard devation in the week leading up to the latest data for introducing variability between particles into the IC


M = zeros(size(It));
M(:, 1:length(ItoA)) = repmat(ItoA, nParticles, 1);       % create a zero-padded matrix of the ItoA distribution
C = fastConv(It, M, 2);                                 % convolution of each row of It with ItoA
IAt = [zeros(nParticles, 1), C(:, 1:nSteps-1)];          % infections by pseudo-date of admission

% Loop through age groups and sample from the fitted GPR models in each age group
nAges = length(ageBreaks);
Alpha = 0.05;   % Note Alpha is the significance level for confidence intervals from the fitted GPRs but since the CI output is not used this the value of Alpha does not affect model outputs. 
mdlCaseSamp = zeros(nParticles, nSteps, nAges);
mdlHospSamp = zeros(nParticles, nSteps, nAges);
for iAge = 1:nAges
    if iAge ~= par.refAge
         [mdlCaseOut, covmat] = predictExactWithCov(mdlCase{iAge}.Impl, datenum(t), Alpha );              % mean and cov matrix output from GP regression. 
         T = cholcov(covmat);
         mdlCaseSamp(:, :, iAge) = mdlCaseOut' + randn(nParticles, nSteps)*T;   % Samples realisations from the fitted GPR as a multivariate normal with mean mdlCaseOut and covariance matrix covmat
    else
        mdlCaseSamp(:, :, iAge) = zeros(nParticles, nSteps);
    end
    if fittedFlag(iAge) == 1
       [mdlHospOut, covmat] = predictExactWithCov(mdlHosp{iAge}.Impl, datenum(t), Alpha );      % mean and cov matrix output from GP regression. 
       T = cholcov(covmat);
       mdlHospSamp(:, :, iAge) = mdlHospOut' +  randn(nParticles, nSteps)*T;
    else
        % Calculate bootstrapped estimate of hospitalisation probability for each particle
        bootstrapSample = binornd(mdlHosp{iAge}.nTrials, mdlHosp{iAge}.nSuccess/mdlHosp{iAge}.nTrials, nParticles, 1);        % bootstrap IID sample from Bin(n,p) for each particle
        p = bootstrapSample / mdlHosp{iAge}.nTrials;
        logOdds = log(p./(1-p));
        mdlHospSamp(:, :, iAge) = repmat(logOdds, 1, nSteps);
    end
end
pCasesSamp = exp(mdlCaseSamp)./sum(exp(mdlCaseSamp), 3);       % proportion of cases that are in each age group
pHospSamp = exp(mdlHospSamp)./(1+exp(mdlHospSamp));            % proportion of cases in each age group that are hopsitalised
CHR = sum(pCasesSamp.*pHospSamp, 3);

At = nbinrnd(par.overdispFactorHosp, par.overdispFactorHosp./(IAt.*CHR+par.overdispFactorHosp));

Dt = zeros(nParticles, nSteps);
nLOS = length(LOS_array);
fHosp = pCasesSamp.*pHospSamp./sum(pCasesSamp.*pHospSamp, 3);       % Proportion of hopsitalised cases that are in each age band
for iStep = 1:nSteps
    hospAgeDist = squeeze(fHosp(:, iStep, :));          % matrix of age distribution of hopsitalised cases for each particle at current time step
    LOS_combined_relFreq = hospAgeDist*LOS_relFreq;     % Calculate LOS distribution for each particle at time t(iStep) by weighting the current age distribution with the age-specific LOS distributions
    LOS_combined_relFreq = LOS_combined_relFreq./sum(LOS_combined_relFreq, 2);
    
    %futureDischarges = At(:, iStep).* LOS_combined_relFreq;                                  % Future discharges from today's admissions (expected values)
    futureDischarges = mnrnd(At(:, iStep), LOS_combined_relFreq);                           % Future discharges from today's admissions by sampling from LOS distribution
    if iStep+nLOS-1 <= nSteps
        Dt(:, iStep:iStep+nLOS-1) = Dt(:, iStep:iStep+nLOS-1)+futureDischarges;       % Add today's future discharges to running tally (noting because LOS distribution starts at zero the first column of future discharges happen today)
    else
        Dt(:, iStep:end) = Dt(:, iStep:end)+futureDischarges(:, 1:nSteps-iStep+1);
    end
end

Ht0 = cumsum(At-Dt, 2);          % hospital occupancy starting arbitrarily from zero at start of simulation period
%figure(100); plot(t, Ht0)

% Calculate mean and std. dev. of raw (unadjusted) hopsital occpancy values at time of latest data point, t = tHosp0
Ht0_mean = mean(Ht0(:, t == tHosp0));
Ht0_SD = std(Ht0(:, t == tHosp0));

Htoffset = Ht0 + hospOccLatest - Ht0_mean;      % apply constant offset so particles have the correct mean at t = tHosp0
%figure(101); plot(t, Htoffset)
Htscaled = hospOccLatest + ( Htoffset - hospOccLatest  ) * (hospOccLatestSD/Ht0_SD)  ;     % a rescaled ensemble with the correct SD at latest time point  t = tHosp0
%figure(102); plot(t, Htscaled)
Ht = max(0, Htoffset + Htscaled(:, t == tHosp0)-Htoffset(:, t == tHosp0));                   % don't want to multiplicatively scale each particle for all time, instead an an additive constant (rounded to maintain integer values) to each particle to achieve the same set of values (and hence correct std. dev.) at the specific time point t = tHosp0
%figure(103); plot(t, Ht)
 

% Basic version, just sets mean and SD randomly across particles at t = tHosp0 and then sets negatuive values to 0
%Htrel = Ht0 - Ht0(:, t == tHosp0);  % hospital occupancy relative to time tHosp0 (most recent data)
%Ht = max(0, Htrel + hospOccLatest + hospOccLatestSD*randn(nParticles, 1) );       % offset Ht to set initial condition (mean +/- std. dev.) at t = tHosp0 according to data

                        



