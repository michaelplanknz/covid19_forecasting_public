function B = calcBias(xs, Fs, xData) 

% Compute the bias from a set of quantiles of a forecast for a given data point xData
% Uses linear extrapolation to evaluate the CDF below the lowest (e.g. 5th) above the highest (e.g. 95th) quantile
%
% USAGE: bias = calcBias(xs, Fs, xData)
%
% INPUTS: xs - n x m matrix of x values of the CDF, with each row representing a different distribution corresponding to a forecast output
%         Fs - 1 x m array of CDF values (typically evenly spaced but not requiredf to be) common to all distributions
%         xData - n x 1 array of data points against which the CRPS will be computed for each forecast output
%
% OUTPUTS: B - n x 1 array of bias scores corresponding to the n data points and forecast outputs




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

nCols = length(Fs);

xm = xs;
xm(xs > xData) = nan;
[largest_xs_below_xData, ind1] = max(fliplr(xm), [], 2);           % use fliplr and then mirror ind1 to obtain the index of the *last* value below xData in each row
ind1 = 1+nCols-ind1;

xm = xs;
xm(xs < xData) = nan;
[smallest_xs_above_xData, ind2] = min(xm, [], 2);               % ind1 is tte index for the *first* value above xData in each row





w = (xData - largest_xs_below_xData)./(smallest_xs_above_xData - largest_xs_below_xData);
w(isnan(smallest_xs_above_xData)) = 0;                              % If there is nothing above the data, use the last value below the data (will usually be F=1)
w(isnan(largest_xs_below_xData)) = 1;                               % If there is nothing below the data, use the first value above the data (will usually be F=0)
w(smallest_xs_above_xData == largest_xs_below_xData) = 0.5;          %  For cases where data coincided exactly with a single grid point, use that grid point; if data coincides with multiple grid points, this will average the left-most and right-most such points
interpF = (1-w).*Fs(ind1)' + w.*Fs(ind2)';

% Any bias scores where xData or a value of xs is nan are returned as nan
B = nan(nRows, 1);
B(~nanFlag) = 1-2*max(0, min(1, interpF));

