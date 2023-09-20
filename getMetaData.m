function meta = getMetaData()

% Function defining meta data on Health Districts and Regions
%
% USAGE: meta = getMetaData()
%
% OUTPUTS: meta - structure with following ields 
%               * DHBnames - array of Health District names (DHBs)
%               * regoinNames - array of Region names
%               * regionLookup - table whose 1st column is Health District names and 2nd colum is the region to which that District belongs

% Create lookup table mapping Health Districts to Regions
DHB = categorical(["Northland"; "Waitemata"; "Auckland"; "Counties Manukau"; "Waikato"; "Bay of Plenty"; "Lakes"; "Tairawhiti"; "Taranaki"; "Whanganui"; "Hawke's Bay"; "Wairarapa"; "Capital & Coast/Hutt"; "MidCentral"; "Nelson Marlborough"; "Canterbury/West Coast"; "South Canterbury"; "Southern"]);
region = categorical([repmat("Northern_region", 4, 1); repmat("Midland_region", 5, 1); repmat("Central_region", 5, 1); repmat("Southern_region", 4, 1) ]);
meta.regionLookup = table(DHB, region);

meta.DHBnames = DHB;
meta.regionNames = unique(region);

