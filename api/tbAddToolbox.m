function results = tbAddToolbox(varargin)
% Add a toolbox to the toolbox configuration, fetch it, add it to the path.
%
% The goal here is to make it a one-liner to add a new toolbox to the
% working configuration.  So this is just a utility wrapper on other
% toolbox functions.
%
% results = tbAddToolbox( ... name, value) creates a new toolbox record
% based on the given name-value pairs and adds it to the toolbox
% configuration.  See tbToolboxRecord() for recognized names.
%
% You can also specify additional name-value pairs to specify
% how toolboxes should be deployed.  See tbDeployToolboxes() which also
% shares parameters with this function.
%
% If a toolbox with the same 'name" already exists in the configuration, it
% will be replaced with the new one.
%
% 2016 benjamin.heasly@gmail.com

%% Make a new toolbox record.
newRecord = tbToolboxRecord(varargin{:});

%% Deploy just the new toolbox.
results = tbDeployToolboxes( ...
    varargin{:}, ...
    'config', newRecord, ...
    'reset', 'as-is');

if 0 ~= results.status
    error('AddToolbox:deployError', 'Could not deploy toolbox with name "%s": %s', ...
        results.name, results.message);
end

%% Add new toolbox to the existing config.
config = tbReadConfig(varargin{:});
if isempty(config) || ~isstruct(config) || ~isfield(config, 'name')
    config = newRecord;
else
    isExisting = strcmp({config.name}, newRecord.name);
    if any(isExisting)
        insertIndex = find(isExisting, 1, 'first');
    else
        insertIndex = numel(config) + 1;
    end
    config(insertIndex) = newRecord;
end

%% Write back the new config. after success.
tbWriteConfig(config, varargin{:});

