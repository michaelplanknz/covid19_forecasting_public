function hospData = getHospData(meta)

% Function to read in hopsital occupancy data from MOH-provided file covid-cases-in-hospital-counts-location.xlsx which can be downloaded from https://github.com/minhealthnz/nz-covid-data/tree/main/cases
%
% USAGE: hospData = getHospData()
%
% INPUTS: meta - metaData on Health Districts and regoins as returned by getMetaData()
%
% OUTPUTS: hospData - table with the following fields
%            - t - column of dates
%            - area - areaName field (either "National" or a specified Health Distict)
%            - Hosp - hospital occupancy


fNameHosp = sprintf('data/covid-cases-in-hospital-counts-location.xlsx' );
opts = detectImportOptions(fNameHosp, 'Sheet', 'All districts'); % use the "NZ total" sheet not the regional sheets
for iVar = 1:length(opts.VariableNames)
   if opts.VariableNames{iVar} == "Date"
       opts.VariableNames{iVar} = 't';                      % rename the "Date" column as "t"
   end
   if opts.VariableNames{iVar} == "DHB"
       opts.VariableNames{iVar} = 'area';                      % rename the "COVIDCasesInHospital" column as "Hosp" if necessary (it is alreadh "Hosp" on some sheets)
   end
   if opts.VariableNames{iVar} == "COVIDCasesInHospital"
       opts.VariableNames{iVar} = 'Hosp';                      % rename the "COVIDCasesInHospital" column as "Hosp" if necessary (it is alreadh "Hosp" on some sheets)
   end
end
opts = setvartype(opts, 'Hosp', 'double');
opts = setvartype(opts, 'area', 'categorical');

hospData = flipud(readtable(fNameHosp, opts));              % flipud ensures the table is ordered old to new

% Vector of dates
t = unique(hospData.t);
nDates = length(t);

% Merge Capital & Cost with Hutt Valley and Canterbury with West Coast, and create National totals
lbl1a = "Capital and Coast";  lbl1b = "Hutt Valley";  lbl1c = "Capital & Coast/Hutt";
lbl2a = "Canterbury";  lbl2b = "West Coast";  lbl2c = "Canterbury/West Coast";
for iDt = 1:nDates
    dateFlag = hospData.t == t(iDt);
    hospData.Hosp(dateFlag & hospData.area == lbl1a) = hospData.Hosp(dateFlag & hospData.area == lbl1a) + hospData.Hosp(dateFlag & hospData.area == lbl1b);     % Replace area A data with area A plus area B
    hospData.Hosp(dateFlag & hospData.area == lbl2a) = hospData.Hosp(dateFlag & hospData.area == lbl2a) + hospData.Hosp(dateFlag & hospData.area == lbl2b); 
end
hospData(hospData.area == lbl1b | hospData.area == lbl2b, :) = [];                                                                                              % Remove area B data from table
hospData.area(hospData.area == lbl1a) = lbl1c;                                                                                                                  % Replace area A labels with new labels 
hospData.area(hospData.area == lbl2a) = lbl2c;

hospData.area = categorical(hospData.area);

nRegions = length(meta.regionNames);
aggregatedAreaNames = ["National"; meta.regionNames];


% Add rows to table for national and regional totals to go in:
nExtraRows = length(t)*length(aggregatedAreaNames);
hospData = [hospData; table(repmat(t, length(aggregatedAreaNames), 1), repelem(aggregatedAreaNames, length(t), 1), nan(nExtraRows, 1), 'VariableNames', {'t', 'area', 'Hosp'} ) ];
for iDt = 1:nDates
    dateFlag = hospData.t == t(iDt);
    hospData.Hosp(dateFlag & hospData.area == "National") = sum(hospData.Hosp(dateFlag & ismember(hospData.area, meta.DHBnames)) );    
    for iRegion = 1:nRegions
        DHBlist = meta.regionLookup.DHB(meta.regionLookup.region == meta.regionNames(iRegion));
        hospData.Hosp(dateFlag & hospData.area == meta.regionNames(iRegion)) = sum(hospData.Hosp(dateFlag & ismember(hospData.area, DHBlist )) );        
    end
end




