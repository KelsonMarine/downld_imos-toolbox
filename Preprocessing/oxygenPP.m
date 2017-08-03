function sample_data = oxygenPP( sample_data, qcLevel, auto )
%OXYGENPP adds an oxygen solubility at atmospheric pressure variable 
% OXSOL_SURFACE and other oxygen data to the given data sets.
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive consistent oxygen 
% data when possible from salinity, temperature and pressure. It adds oxygen 
% data as new variables in the data sets. Data sets which do not contain
% oxygen, temperature, pressure and depth variables or nominal depth 
% information are left unmodified.
%
% From : http://doi.org/10.13155/39795 (note: Argo DOXY is IMOS DOX2)
%
% The unit of DOXY is umol/kg in Argo data and the oxygen measurements are sent from Argo floats in 
% another unit such as umol/L for the Optode and ml/L for the SBE-IDO. Thus the unit conversion is carried out by DACs as follows:
%   O2 [umol/L] = 44.6596 . O2 [ml/L]
%   O2 [umol/kg] = O2 [umol/L] / pdens
% Here, pdens is the potential density of water [kg/L] at zero pressure and at the potential temperature 
% (e.g., 1.0269 kg/L; e.g., UNESCO, 1983). The value of 44.6596 is derived from the molar volume of the oxygen gas, 22.3916 L/mole, 
% at standard temperature and pressure (0 C, 1 atmosphere; e.g., Garcia and Gordon, 1992). 
% This unit conversion follows the "Recommendations on the conversion between oxygen quantities for Bio-Argo floats and other autonomous sensor platforms" 
% by SCOR Working Group 142 on "Quality Control Procedures for Oxygen and Other Biogeochemical Sensors on Floats and Gliders" [RD13] . 
% The unit conversion should always be done with the best available temperature, i.e., TEMP of the CTD unit.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
%  Input Parameters
%       TEMP, PSAL, PRES_REL/PRES or DEPTH/nominal_depth
%       DOX
%       DOXY
%       DOXS
%       DOX1
%       DOX2
%
% Outputs:
%   sample_data - the same data sets, with oxygen (umol/kg) 
%                 oxygen saturation, oxygen solubility variables added.
% 
% Output Parameters
%       OXSOL_SURFACE
%       DOX1
%       DOX2
%       DOXS

%
% Author:       Peter Jansen <peter.jansen@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  tempIdx       = getVar(sam.variables, 'TEMP');
  psalIdx       = getVar(sam.variables, 'PSAL');
  
  [presRel, presName] = getPresRelForGSW(sam);
  
  doxIdx        = getVar(sam.variables, 'DOX');
  doxyIdx       = getVar(sam.variables, 'DOXY');
  dox1Idx       = getVar(sam.variables, 'DOX1');
  dox2Idx       = getVar(sam.variables, 'DOX2');
  doxsIdx       = getVar(sam.variables, 'DOXS');
  
  % cancel if psal, temp, pres/pres_rel or depth/nominal depth and any DO parameter not present in data set
  if ~(psalIdx && tempIdx && ~isempty(presName) && (doxIdx || doxyIdx || dox1Idx || dox2Idx || doxsIdx)), continue; end
  
  % data set already contains dissolved oxygen DOX1/DOX2 or DOXS
  if (dox1Idx && dox2Idx && doxsIdx), continue; end
  
  temp = sam.variables{tempIdx}.data;
  psal = sam.variables{psalIdx}.data;
  
  % calculate the potential temperature with a reference sea pressure of 0dbar
  potTemp = sw_ptmp(psal, temp , presRel, 0);

  % calculate the potential density at 0dbar from potential temperature
  potDens = sw_dens0(psal, potTemp);
  potDensComment = ['Potential density at atmospheric pressure was derived ' ...
      'from TEMP, PSAL and ' presName 'using sw_dens0 and sw_ptmp ' ...
      'from the SeaWater toolbox (EOS-80) v1.1.'];

  % get dimensions and coordinates values from temperature
  dimensions = sam.variables{tempIdx}.dimensions;
  if isfield(sam.variables{tempIdx}, 'coordinates')
      coordinates = sam.variables{tempIdx}.coordinates;
  else
      coordinates = '';
  end
  
  % calculate oxygen solubility at atmospheric pressure
  oxsolSurf = gsw_O2sol_SP_pt(psal, potTemp); % sea bird calculates OXSOL using psal and local temperature, not potential temperature
  oxsolSurfComment = ['OXSOL_SURFACE derived from TEMP, PSAL and ' presName ...
      ' using gsw_O2sol_SP_pt from the Gibbs-SeaWater toolbox (TEOS-10) ' ...
      'v3.05 and sw_ptmp from the SeaWater toolbox (EOS-80) v1.1.'];
  
  % add oxygen solubility at atmospheric pressure as new variable in data set
  sample_data{k} = addVar(...
      sample_data{k}, ...
      'OXSOL_SURFACE', ...
      oxsolSurf, ...
      dimensions, ...
      ['oxygenPP.m: ' oxsolSurfComment], ...
      coordinates);
  
  historyComment = oxsolSurfComment;
  
  SBEProcManualRef = 'See SeaBird data processing manual (http://www.seabird.com/document/sbe-data-processing-manual).';
  argoO2ProcRef    = 'See Argo oxygen processing (http://doi.org/10.13155/39795).';
  
  % calculate DOX1 when necessary with order of preference from DOX, DOXY, DOX2 and DOXS
  dox1Comment = '';
  if dox1Idx == 0 % umol/l
      if doxsIdx % percent of saturation
          doxs = sam.variables{doxsIdx}.data;
          dox1 = doxs .* oxsolSurf .* potDens / 1000; % 1m3 = 1000l
          dox1Comment = ['DOX1 derived using DOX1 = DOXS * OXSOL_SURFACE * ' ...
              'potential density / 1000. ' oxsolSurfComment ' ' potDensComment ' ' ...
              SBEProcManualRef ' ' argoO2ProcRef];
      end
      if dox2Idx % umol/kg
          dox2 = sam.variables{dox2Idx}.data;
          dox1 = dox2 .* potDens / 1000; % 1m3 = 1000l
          dox1Comment = ['DOX1 derived using DOX1 = (DOX2 / 1000) * ' ...
              'potential density. ' potDensComment ' ' argoO2ProcRef];
      end
      if doxyIdx % mg/l
          doxy = sam.variables{doxyIdx}.data;
          dox1 = doxy * (1000 / 31.9988); % O2 molar mass = 31.9988g/mol
          dox1Comment = 'DOX1 derived using DOX1 = DOXY * (1000 / 31.9988).';
      end
      if doxIdx % ml/l
          dox = sam.variables{doxIdx}.data;
          dox1 = dox * 44.6596; % 1ml/l = 44.6596umol/l
          dox1Comment = 'DOX1 derived using DOX1 = DOX * 44.6596.';
      end
      
      % add dissolved oxygen in umol/l data as new variable in data set
      sample_data{k} = addVar(...
          sample_data{k}, ...
          'DOX1', ...
          dox1, ...
          dimensions, ...
          ['oxygenPP.m: ' dox1Comment], ...
          coordinates);
      
      historyComment = [historyComment ' ' dox1Comment];
  end
  
  % calculate DOX2 when necessary with order of preference from DOX, DOXY, DOX1, DOXS
  dox2Comment = '';
  if dox2Idx == 0 % umol/kg
      if doxsIdx % percent of saturation
          doxs = sam.variables{doxsIdx}.data;
          dox2 = doxs / 100 .* oxsolSurf;
          dox2Comment = ['DOX2 derived using DOX2 = DOXS / 100 * OXSOL_SURFACE. ' ...
              oxsolSurfComment ' ' SBEProcManualRef]; % although SeaBird uses local temperature
      end
      if dox1Idx % umol/l
          dox1 = sam.variables{dox1Idx}.data;
          dox2 = dox1 * 1000 ./ potDens; % 1m3 = 1000l
          dox2Comment = ['DOX2 derived using DOX2 = DOX1 * 1000 / ' ...
              'potential density. ' potDensComment ' ' argoO2ProcRef];
      end
      if doxyIdx % mg/l
          doxy = sam.variables{doxyIdx}.data;
          dox2 = doxy * (1000 / 31.9988) * 1000 ./ potDens; % O2 molar mass = 31.9988g/mol
          dox2Comment = ['DOX2 derived using DOX2 = DOXY * (1000 / 31.9988) / ' ...
              'potential density. ' potDensComment ' ' argoO2ProcRef];
      end
      if doxIdx % ml/l
          dox = sam.variables{doxIdx}.data;
          dox2 = dox * 44.6596 * 1000 ./ potDens; % 1ml/l = 44.6596umol/l
          dox2Comment = ['DOX2 derived from using = DOX * 44.6596 * 1000 / ' ...
              'potential density. ' potDensComment ' ' argoO2ProcRef];
      end
      
      % add dissolved oxygen in umol/kg data as new variable in data set
      sample_data{k} = addVar(...
          sample_data{k}, ...
          'DOX2', ...
          dox2, ...
          dimensions, ...
          ['oxygenPP.m: ' dox2Comment], ...
          coordinates);
      
      historyComment = [historyComment ' ' dox2Comment];
  else
      dox2 = sam.variables{dox2Idx}.data;
  end
      
  % calculate DOXS from DOX2 and OXSOL_SURFACE
  doxsComment = '';
  if doxsIdx == 0
      doxs = 100 * dox2 ./ oxsolSurf;
      doxsComment = ['DOXS derived using DOXS = 100 * DOX2 / OXSOL_SURFACE. ' ...
          oxsolSurfComment ' ' SBEProcManualRef]; % although SeaBird uses local temperature
      
      % add oxygen saturation in % data as new variable in data set
      sample_data{k} = addVar(...
          sample_data{k}, ...
          'DOXS', ...
          doxs, ...
          dimensions, ...
          ['oxygenPP.m: ' doxsComment], ...
          coordinates);
      
      historyComment = strtrim([historyComment ' ' doxsComment]);
  end

  history = sample_data{k}.history;
  if isempty(history)
      sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), ['oxygenPP.m: ' historyComment]);
  else
      sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), ['oxygenPP.m: ' historyComment]);
  end
end
