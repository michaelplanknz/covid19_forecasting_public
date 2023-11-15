function h = makePlots(results, tMin, tMax, highlightCIFlag, graphTitle)

tHospLag = 0;                  % Grey out most recent hospital admission data for this many days to show points most likely to be icomplete due to reporting lag
greyCol = [0.6 0.6 0.6];
greenCol = [0 0.6 0.2];

% h = figure;
% h.Position = [   131         169        1226         698];
% plot(results.t, results.Rq(:, 10), 'b-')
% hold on
% plot(results.t, results.Rq(:, 1:2:end), 'Color', greyCol)
% ylabel('effective reproduction number')
% xlim([tMin, tMax])
% if length(unique(results.forecastDate)) == 1
%    xline( results.forecastDate(1), 'k:');
% end

fd = results.forecastDate(~isnat(results.forecastDate));
uniqueForecastFlag = length(unique(fd)) == 1;



h = figure;
h.Position = [    1          41        1680         933];
subplot(2, 2, 1)
plot(results.t, results.Cq(:, 1:2:end), 'Color', greyCol);
hold on
plot(results.t, results.Cq(:, 10), 'b-');
if highlightCIFlag
   iOut = (results.casesInFlag == 0);
   plot(results.t(~iOut), results.nCases(~iOut), '.', 'color', greenCol);
   plot(results.t(iOut), results.nCases(iOut), 'r.');
   hc = get(gca, 'Children');
   legend(hc([3 4 2 1]), "forecast (median)", "forecast (quantiles)", "data (inside 90% interval)", "data (outside 90% interval)",  'location', 'NorthEast');
else
   plot(results.t, results.nCases, '.', 'color', greenCol);
   hc = get(gca, 'Children');
   legend(hc([2 3 1]), "forecast (median)", "forecast (quantiles)", "data", 'location', 'NorthEast');
end
if uniqueForecastFlag
   xline( fd(1), 'k:', 'HandleVisibility', 'off');
end
ylabel('daily cases')
xlim([tMin, tMax])
yl = ylim; yl(1) = 0; ylim(yl);
title( "(a) " + graphTitle + "cases")

subplot(2, 2, 2)
plot(results.t(results.t <= tMax-3), results.Cq_smoothed(results.t <= tMax-3, 1:2:end), 'Color', greyCol)
hold on
plot(results.t(results.t <= tMax-3), results.Cq_smoothed(results.t <= tMax-3, 10), 'b-')                    % omit last 3 points due to bias in moving average    
plot(results.t, results.nCasesSmoothed, '.', 'color', greenCol)
if highlightCIFlag
   iOut = (results.casesSmoothedInFlag == 0);
   plot(results.t(iOut), results.nCasesSmoothed(iOut), 'r.') 
end
if uniqueForecastFlag
   xline( fd, 'k:');
end
ylabel('daily cases')
xlim([tMin, tMax])
yl = ylim; yl(1) = 0; ylim(yl);
title( "(b) " + graphTitle + "cases (7DRA)")

iHospLag = find(~isnan(results.nHosp_DOA), 1, 'last')-tHospLag;     % Index of last existing datapoint minus number of days to "grey out" 
subplot(2, 2, 3)
plot(results.t, results.Aq(:, 1:2:end), 'Color', greyCol)
hold on
plot(results.t, results.Aq(:, 10), 'b-')
plot(results.t(1:iHospLag), results.nHosp_DOA(1:iHospLag), '.', 'color', greenCol)
if highlightCIFlag
   iOut = (results.admInFlag == 0);
   plot(results.t(iOut), results.nHosp_DOA(iOut), 'r.') 
end
plot(results.t(iHospLag+1:end), results.nHosp_DOA(iHospLag+1:end), '.', 'Color', greyCol, 'HandleVisibility', 'off')
if uniqueForecastFlag
   xline( fd, 'k:');
end
ylabel('new daily admissions')
xlim([tMin, tMax])
yl = ylim; yl(1) = 0; ylim(yl);
title("(c) " +  graphTitle + "admissions")

subplot(2, 2, 4)
plot(results.t, results.Hq(:, 1:2:end), 'Color', greyCol)
hold on
plot(results.t, results.Hq(:, 10), 'b-')
plot(results.t, results.Hosp, '.', 'color', greenCol)
if highlightCIFlag
   iOut = (results.occInFlag == 0);
   plot(results.t(iOut), results.Hosp(iOut), 'r.') 
end
if uniqueForecastFlag
   xline( fd, 'k:');
end
ylabel('hopsital occupancy')
xlim([tMin, tMax])
yl = ylim; yl(1) = 0; ylim(yl);
title("(d) " +  graphTitle + "occupancy")

drawnow


