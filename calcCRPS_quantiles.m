function score = calcCRPS_quantiles(xs, Fs, xData)

% Compute the CRPS from a set of quantiles of a forecast for a given data point xData
% Uses linear extrapolation to evaluate the CDF below the lowest (e.g. 5th) above the highest (e.g. 95th) quantile
%
% USAGE: score = calcCRPS_quant(xs, Fs, xData)
%
% INPUTS: xs - n x m matrix of x values of the CDF, with each row representing a different distribution corresponding to a forecast output
%         Fs - 1 x m array of CDF values (typically evenly spaced but not requiredf to be) common to all distributions
%         xData - n x 1 array of data points against which the CRPS will be computed for each forecast output
%
% OUTPUTS: score - n x 1 array of scores corresponding to the n data points and forecast outputs

% Remove any rows where xData or a value of xs is nan (values of score for
% these rows will be returned as nan)
nRows = length(xData);
nanFlag = sum(isnan(xs), 2) > 0 | isnan(xData);
xs(nanFlag, :) = [];
xData(nanFlag) = [];


% If lowest/highest quantiles are away from {0,1} respectively, add an extra "sample point" at 0 and 1 by linear extrapolation of the CDF
if Fs(1) > 0
    xs = [xs(:, 1) - Fs(1)*(xs(:, 2)-xs(:, 1))/(Fs(2)-Fs(1)), xs];
    Fs = [0, Fs];
end
if Fs(end) < 1
    xs = [xs, xs(:, end) + (1-Fs(end))*(xs(:, end)-xs(:, end-1))/(Fs(end)-Fs(end-1)) ];
    Fs = [Fs, 1];
end

% Compute difference arrays and indicator variables needed to calculate
% integral
dx = diff(xs, [], 2);
dF = diff(Fs);
dF2 = diff(Fs.^2);
dF3 = diff(Fs.^3);
dataBelowFlag = xData <= xs;
dataInFlag = dataBelowFlag(:, 2:end)-dataBelowFlag(:, 1:end-1);

% Compute integral of (F(x)-I(x>xData))^2 for x outside the range xs(1) to
% xs(end) (if xData falls outside this range) 
% This is expressed as the value of the intergal from xData to xs(1) plus the value of the intergal from xs(end) to xData if xData falls outside this range
intOut = max(0, xs(:, 1)-xData) + max(0, xData-xs(:, end));  

% Compute the intergal of (F(x)-I(x>xData))^2 between xs(1) and xs(end)
% Note: nansum because any intervals with dx=0 will be 0/0=nan but should be counted as 0
xdm = xData-xs(:, 1:end-1);
intIn = nansum(dx .* (dF3./(3*dF) + dataBelowFlag(:, 2:end).*(1 - dF2./dF)) + dataInFlag.*(dF.*xdm.^2./dx + (2*Fs(1:end-1)-1).*xdm ), 2) ;     

% Any scores where xData or a value of xs is nan are returned as nan
score = nan(nRows, 1);
score(~nanFlag) = intOut + intIn;

