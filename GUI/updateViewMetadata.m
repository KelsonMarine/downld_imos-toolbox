function updateViewMetadata(parent, sample_data)
%UPDATEVIEWMETADATA Updates the display of metadata for the given data set in the given parent
% figure/uipanel.
%
% This function displays NetCDF metadata contained in the given sample_data 
% struct in the given parent figure/uipanel. The tabbedPane function is used 
% to separate global/dimension/variable attributes. Users are able to
% modify field values.
%
% Inputs:
%   parent         - handle to the figure/uipanel in which the metadata should
%                    be displayed.
%   sample_data    - struct containing sample data.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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
  error(nargchk(2, 2, nargin));

  if ~ishandle(parent),      error('parent must be a handle');           end
  if ~isstruct(sample_data), error('sample_data must be a struct');      end
  
  varData  = {};
  dimData  = {};
  
  %% create data sets
  
  dateFmt = readProperty('toolbox.timeFormat');
  
  globs = orderfields(sample_data);
  globs = rmfield(globs, 'meta');
  globs = rmfield(globs, 'variables');
  globs = rmfield(globs, 'dimensions');
  
  dims = sample_data.dimensions;
  for k = 1:length(dims)
    dims{k} = orderfields(rmfield(dims{k}, {'data', 'flags'})); 
  end
  
  vars = sample_data.variables;
  for k = 1:length(vars)
    vars{k} = orderfields(rmfield(vars{k}, {'data', 'dimensions', 'flags'})); 
  end
  
  % create a cell array containing global attribute data
  globData = [fieldnames(globs) struct2cell(globs)];
  
  % create cell array containing dimension 
  % attribute data (one per dimension)
  for k = 1:length(dims), 
    dimData{k} = [fieldnames(dims{k}) struct2cell(dims{k})];
  end
  
  % create cell array containing variable 
  % attribute data (one per variable)
  for k = 1:length(vars)
    
    varData{k} = [fieldnames(vars{k}) struct2cell(vars{k})];
  end
  
  %% update uitables
  
  % update a uitable for each data set
  updateTable(globData, '', 'global', dateFmt);
  
  for k = 1:length(dims)
    updateTable(...
      dimData{k}, ['dimensions{' num2str(k) '}'], lower(dims{k}.name), dateFmt);
  end
  
  for k = 1:length(vars)
    updateTable(...
      varData{k}, ['variables{'  num2str(k) '}'], 'variable', dateFmt);
  end

  function updateTable(data, prefix, tempType, dateFmt)
  % Updates a uitable which contains the given data. 
  
    % format data - they're all made into strings, and cast 
    % back when edited. also we want date fields to be 
    % displayed nicely, not to show up as a numeric value
    for k = 1:length(data)
      
      % get the type of the attribute
      t = templateType(data{k,1}, tempType);
      
      switch t
        
        % format dates
        case 'D',  
          data{k,2} = datestr(data{k,2}, dateFmt);
        
        % make sure numeric values are not rounded (too much)
        case 'N',
          data{k,2} = sprintf('%.10f', data{k,2});
        
        % make everything else a string - i'm assuming that when 
        % num2str is passed a string, it will return that string 
        % unchanged; this assumption holds for at least r2008, r2009
        otherwise, data{k,2} = num2str(data{k,2});
      end
    end
    
    % get the table and update it
    hTable = findobj('Tag', ['metadataTable' prefix]);
    set(hTable, 'Data', data);
  end
end