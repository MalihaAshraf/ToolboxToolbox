classdef TbIncludeTest  < matlab.unittest.TestCase
    % Test transitive toolbox resolution.
    %
    % The Toolbox Toolbox should be able to nest configurations using the
    % "include" record type.  It should be able to avoid "include" loops.
    % It should be able to include toolboxes from a registry of JSON files.
    % It should resolbe and deploy records in the same order they were
    % included.
    %
    % 2016 benjamin.heasly@gmail.com
    
    properties
        tempFolder = fullfile(tempdir(), 'TbIncludeTest');
        originalMatlabPath;
    end
    
    methods (TestMethodSetup)
        function clearTempFolder(obj)
            if 7 == exist(obj.tempFolder, 'dir')
                rmdir(obj.tempFolder, 's');
            end
            mkdir(obj.tempFolder);
        end
        
        function saveOriginalMatlabState(obj)
            obj.originalMatlabPath = path();
            tbResetMatlabPath('reset', 'full');
        end
    end
    
    methods (TestMethodTeardown)
        function restoreOriginalMatlabState(obj)
            path(obj.originalMatlabPath);
        end
    end
    
    methods (Test)
        function testNoInclude(obj)
            % trivial case with nothing to include
            originalConfig = [ ...
                tbToolboxRecord('name', 'simple-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'simple-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'simple-3', 'type', 'git'), ...
                ];
            
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(tbGetPersistentPrefs, originalConfig, tbDefaultRegistry());
            obj.assertEqual(resolvedConfig, originalConfig);
        end
        
        function testNoDuplicates(obj)
            % include one config from another, exclude duplicates by name
            includedConfig = [ ...
                tbToolboxRecord('name', 'included-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'included-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'included-3', 'type', 'git'), ...
                tbToolboxRecord('name', 'duplicate', 'type', 'git'), ...
                ];
            includedConfigPath = fullfile(obj.tempFolder, 'includeMe.json');
            tbWriteConfig(includedConfig, 'configPath', includedConfigPath);
            
            originalConfig = [ ...
                tbToolboxRecord('name', 'original-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'original-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'duplicate', 'type', 'git'), ...
                tbToolboxRecord( ...
                'name', 'includeIt', ...
                'type', 'include', ...
                'url', includedConfigPath), ...
                ];
            
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, originalConfig, tbDefaultRegistry());
            resolvedNames = {resolvedConfig.name};
            expectedNames = {'original-1', 'original-2', 'duplicate', 'included-1', 'included-2', 'included-3'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
        
        function testIndirectInclude(obj)
            % include a config indirectly through an intermediate
            baseConfig = [ ...
                tbToolboxRecord('name', 'base-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'base-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'base-3', 'type', 'git'), ...
                ];
            baseConfigPath = fullfile(obj.tempFolder, 'base.json');
            tbWriteConfig(baseConfig, 'configPath', baseConfigPath);
            
            middleConfig = tbToolboxRecord( ...
                'name', 'base-ref', ...
                'type', 'include', ...
                'url', baseConfigPath);
            middleConfigPath = fullfile(obj.tempFolder, 'middle.json');
            tbWriteConfig(middleConfig, 'configPath', middleConfigPath);
            
            originalConfig = [ ...
                tbToolboxRecord('name', 'original-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'original-2', 'type', 'git'), ...
                tbToolboxRecord( ...
                'name', 'middle-ref', ...
                'type', 'include', ...
                'url', middleConfigPath), ...
                ];
            
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, originalConfig, tbDefaultRegistry());
            resolvedNames = {resolvedConfig.name};
            expectedNames = {'original-1', 'original-2', 'base-1', 'base-2', 'base-3'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
        
        function testReflexiveInclude(obj)
            % let a config include itself harmlessly
            selfConfigPath = fullfile(obj.tempFolder, 'self.json');
            selfConfig = [ ...Include
                tbToolboxRecord('name', 'self-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'self-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'self-3', 'type', 'git'), ...
                tbToolboxRecord( ...
                'name', 'self-ref', ...
                'type', 'include', ...
                'url', selfConfigPath)
                ];
            tbWriteConfig(selfConfig, 'configPath', selfConfigPath);
            
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, selfConfig, tbDefaultRegistry());
            resolvedNames = {resolvedConfig.name};
            expectedNames = {'self-1', 'self-2', 'self-3'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
        
        function testSymmetricInclude(obj)
            % let two configs include each other harmlessly
            redConfigPath = fullfile(obj.tempFolder, 'red.json');
            blueConfigPath = fullfile(obj.tempFolder, 'blue.json');
            redConfig = [ ...
                tbToolboxRecord('name', 'red-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'red-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'red-3', 'type', 'git'), ...
                tbToolboxRecord( ...
                'name', 'blue-ref', ...
                'type', 'include', ...
                'url', blueConfigPath)
                ];
            tbWriteConfig(redConfig, 'configPath', redConfigPath);
            
            blueConfig = [ ...
                tbToolboxRecord('name', 'blue-1', 'type', 'git'), ...
                tbToolboxRecord('name', 'blue-2', 'type', 'git'), ...
                tbToolboxRecord('name', 'blue-3', 'type', 'git'), ...
                tbToolboxRecord( ...
                'name', 'red-ref', ...
                'type', 'include', ...
                'url', redConfigPath)
                ];
            tbWriteConfig(blueConfig, 'configPath', blueConfigPath);
            
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, redConfig, tbDefaultRegistry());
            resolvedNames = {resolvedConfig.name};
            expectedNames = {'red-1', 'red-2', 'red-3', 'blue-1', 'blue-2', 'blue-3'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
        
        function testLocalRegistry(obj)
            % locate a test registry
            pathHere = fileparts(mfilename('fullpath'));
            localRegistry = tbToolboxRecord( ...
                'name', 'TestRegistry', ...
                'type', 'local', ...
                'url', fullfile(pathHere, 'fixture', 'registry'));
            prefs = tbParsePrefs(...
                tbGetPersistentPrefs, 'registry', localRegistry);
            
            % deploy the "red" toolbox by name
            %   red includes "blue"
            %   blue includes "green"
            config = tbToolboxRecord('name', 'red');
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, config, prefs);
            resolvedNames = {resolvedConfig.name};
            expectedNames = { ...
                'red-1', 'red-2', 'red-3', ...
                'blue-1', 'blue-2', 'blue-3', ...
                'green-1', 'green-2', 'green-3'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
        
        function testLocalRegistryOrder(obj)
            % locate a test registry
            pathHere = fileparts(mfilename('fullpath'));
            localRegistry = tbToolboxRecord( ...
                'name', 'TestRegistry', ...
                'type', 'local', ...
                'url', fullfile(pathHere, 'fixture', 'registry'));
            prefs = tbParsePrefs(...
                tbGetPersistentPrefs, 'registry', localRegistry);
            
            % deploy "red", then "different".
            % "blue" and "green" should be inserted near "red",
            % not appended after "different"
            config = [ ...
                tbToolboxRecord('name', 'red'), ...
                tbToolboxRecord('name', 'different')];
            resolvedConfig = TbIncludeStrategy.resolveIncludedConfigs(...
                tbGetPersistentPrefs, config, prefs);
            resolvedNames = {resolvedConfig.name};
            expectedNames = { ...
                'red-1', 'red-2', 'red-3', ...
                'blue-1', 'blue-2', 'blue-3', ...
                'green-1', 'green-2', 'green-3', ...
                'different'};
            obj.assertEqual(resolvedNames, expectedNames);
        end
    end
end
