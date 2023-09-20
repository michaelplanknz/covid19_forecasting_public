function DOW_effect = findDOW_effect(epiData, nDaysDOW)

% Function to estimate seven "day of the week" effects, by calculating the average of the daily cases to the 7-day rolling average
%
% USAGE: DOW_effect = findDOW_effect(epiData, nDaysDOW)
%
% INPUTS: epiData - table of epi data
%         nDaysDOW - maximum number of days over which to fit the day-of-the week effects
%
% OUTPUTS: DOW_effect - vector of 7 effects, for days which are equal to 0:6 modulo 7

i2 = length(epiData.t)-3;
i1 = max(1, i2-nDaysDOW+1);
epiData = epiData(i1:end-3, :);      % exclude last three days as the smoothed value is based on < 7 days worth of data and is systematically skewed

effectSize = epiData.nCases./epiData.nCasesSmoothed;
DOW = mod(datenum(epiData.t), 7);
DOW_effect = zeros(1, 7);
for iDow = 1:7
    DOW_effect(iDow) = mean(effectSize(DOW == iDow-1));
end
DOW_effect = DOW_effect/mean(DOW_effect);

