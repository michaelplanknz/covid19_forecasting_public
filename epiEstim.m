function [Rt_est, Rt_est_CI, postShape, postScale] = epiEstim(nCases, wt, a, b, windowSize, Alpha)

% Code to implement the epiEstim method for estimating the time-varying
% effective reproduction number Reff - see Cori et al for details
%
% USAGE [Rt_est, Rt_est_CI] = epiEstim(nCases, wt, a, b, windowSize, Alpha)
%
% INPUTS: nCases - a row vector of daily cases (or a matrix whose rows are
% vectors of daily cases to be treated independently)
%         wt - a vector of PMF values for the generation interval
%         distribution by day
%         a, b - prior parameters of a gamma distribution for Reff
%         windowSize - size of the observation window (in days)
%         Alpha - significance level for the confidence interval required
%         (e.g. Alpha=0.05 for a 95% CI)
%
% OUTPUTS: Rt_est - posterior median estimate for Reff by day
%          Rt_est_CI - lower and upper bounds of the 95% posterior CrI for
%          Reff


[nSeries, nDays] = size(nCases);

% Make sure wt is a normalised PMF
wt = wt/sum(wt);


c = zeros(nSeries, nDays+length(wt)-1);
% Analyse each for of nCases one at a time
for iSeries = 1:nSeries
    % Convolution of nCases with generation interval PMF (quantifying
    % contribution to force of infection by day)
    c(iSeries, :) = conv(nCases(iSeries, :), wt);
end
% Pad with a lead zero and combine each time series of c into a single
% matrix
Gamma = [zeros(nSeries, 1), c(:, 1:nDays-1)];

% Calculate posterior shape and scale parameters using formulae from Cori
% et al
nc = [zeros(nSeries, 1), cumsum(nCases, 2)];
nr = nc(:, windowSize+1:end)-nc(:, 1:end-windowSize);
gc = [zeros(nSeries, 1), cumsum(Gamma, 2)];
gr = gc(:, windowSize+1:end)-gc(:, 1:end-windowSize);
postShape = a+nr;
postScale = 1./(1/b+gr);

% Calculate mean/median and CI
Rt_est = [nan(nSeries, windowSize-1), gaminv(1/2, postShape, postScale)]; % posterior median
%Rt_est = [nan(1, windowSize-1), postShape.*postScale];              % posterior mean
Rt_est_CI = zeros(2*nSeries, size(Rt_est, 2));
Rt_est_CI(1:nSeries, :) = [nan(nSeries, windowSize-1), gaminv(Alpha/2, postShape, postScale)];
Rt_est_CI(nSeries+1:2*nSeries, :) = [nan(nSeries, windowSize-1), gaminv(1-Alpha/2, postShape, postScale)];


