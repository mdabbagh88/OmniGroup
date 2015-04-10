#!/usr/bin/ruby
#
# Copyright 2010-2012 Omni Development, Inc. All rights reserved.
#
# This software may only be used and reproduced according to the
# terms in the file OmniSourceLicense.html, which should be
# distributed with this project and can also be found at
# <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
#
# $Id$

# Very minimal class for getting informtion out of an Xcode xcodeproj file

gem_path = Pathname.new(File.dirname(__FILE__) + "/plist-3.1.0/lib").realpath.to_s
$: << gem_path
require 'plist'

module Xcode
end

class Xcode::Object
  attr_reader :project, :identifier, :dict
  
  def initialize(project, identifier, dict)
    @project = project
    @identifier = identifier
    @dict = dict
  end
end

module Xcode
  
  class XCConfigurationList < Xcode::Object
    attr_reader :configurations
    
    def initialize(project, identifier, dict)
      super
      
      @configurations = dict['buildConfigurations'].map {|configID| project.get(configID, Xcode::XCBuildConfiguration)}
    end
    
  end
end

module Xcode
  class XCBuildConfiguration < Xcode::Object
    attr_reader :name
    attr_reader :settings
    def initialize(project, identifier, dict)
      super
      @name = dict['name']
      fail unless @name
      
      @settings = dict['buildSettings'] || {}
    end
    
    def base_configuration_reference
      ref_id = dict['baseConfigurationReference']
      return nil unless ref_id
      project.get(ref_id, Xcode::FileReference)
    end
  end
end

module Xcode
  class Target < Object
    attr_reader :name
    attr_reader :build_phases
    attr_reader :configuration_list
    
    def initialize(project, identifier, dict)
      super
      @name = dict['name']
      fail unless @name
      
      @build_phases = dict['buildPhases'].map {|phaseID| project.get(phaseID, Xcode::BuildPhase) }
      @configuration_list = project.get(dict['buildConfigurationList'], Xcode::XCConfigurationList)
    end
    
    def configurations
      @configuration_list.configurations
    end
  end
  
  class PBXNativeTarget < Target; end
  class PBXAggregateTarget < Target; end
  class PBXLegacyTarget < Target; end
  class PBXBundleTarget < Target; end
  
end

module Xcode
  class BuildFile < Xcode::Object
    attr_reader :file_reference, :settings
    
    def initialize(project, identifier, dict)
      super
      @file_reference = project.get(dict['fileRef'], Xcode::FileReference, Xcode::Group)
      @settings = dict['settings'] || {}
    end
  
    def has_attribute?(attribute)
      fileSettings = @dict['settings']
      fileAttributes = (fileSettings && fileSettings['ATTRIBUTES']) || [];
      return fileAttributes.index(attribute) != nil
    end
    
    def file_references
      @file_reference.file_references
    end
  end
  
  class PBXBuildFile < BuildFile; end
end

module Xcode
  class FileReference < Xcode::Object
    attr_reader :path, :name
    def initialize(project, identifier, dict)
      super
      @path = dict['path']
      fail "No path found in #{dict}" unless @path

      @name = dict['name'] # optional, if differs from the path
    end
    def file_references
      [self]
    end
    def each_item(&block)
      block.call(self)
    end
  end

  # Products from other included projects are instances of PBXReferenceProxy (like a .a file generated by a dependency on another project)
  class PBXFileReference < FileReference; end
  class PBXReferenceProxy < FileReference; end
  
end

module Xcode
  class Group < Object
    attr_reader :path, :name
    attr_reader :children
    def initialize(project, identifier, dict)
      super
      
      @path = dict['path'] # Optional for groups
      @name = dict['name'] # Optional for groups

      # Can't have groups of groups
      @children = dict['children'].map {|childID| project.get(childID, *self.allowed_child_classes) }
    end
    def allowed_child_classes
      [FileReference, Group]
    end
    def file_references
      @children
    end
    def each_item(&block)
      block.call(self)
      @children.each {|child| child.each_item(&block)}
    end
  end
  
  class PBXGroup < Group; end
  
  class PBXVariantGroup < Group
    def allowed_child_classes
      [FileReference]
    end
  end
  class XCVersionGroup < Group
    def allowed_child_classes
      [FileReference]
    end
  end
  
end

module Xcode
  class BuildPhase < Object
    attr_reader :files
    attr_reader :name
    
    def initialize(project, identifier, dict)
      super

      @files = dict['files'].map {|buildFileID|
        project.get(buildFileID, Xcode::BuildFile)
      }
      
      name = dict['name']
      if name
        @name = "#{self.class.kind_name}: #{name}"
      else
        @name = "#{self.class.kind_name}"
      end
    end

    #  def each_file
  end

  class PBXCopyFilesBuildPhase < BuildPhase
    def self.kind_name
      "Copy Files"
    end
  end
  class PBXFrameworksBuildPhase < BuildPhase
    def self.kind_name
      "Frameworks"
    end
  end
  class PBXHeadersBuildPhase < BuildPhase
    def self.kind_name
      "Headers"
    end
  end
  class PBXResourcesBuildPhase < BuildPhase
    def self.kind_name
      "Resources"
    end
  end
  
  class PBXRezBuildPhase < BuildPhase
    def self.kind_name
      "Rez"
    end
  end
  class PBXShellScriptBuildPhase < BuildPhase
    def self.kind_name
      "Shell Script"
    end
    
    def input_paths
      dict['inputPaths']
    end
    def output_paths
      dict['outputPaths']
    end
    def deployment_only?
      dict['runOnlyForDeploymentPostprocessing'] == 1
    end
    def shell
      dict['shellPath']
    end
    def script
      dict['shellScript']
    end
    
  end
  class PBXSourcesBuildPhase < BuildPhase
    def self.kind_name
      "Sources"
    end
  end

  class PBXAppleScriptBuildPhase < BuildPhase
    def self.kind_name
      "AppleScript"
    end
  end
  
end

# Many of the methods here pre-date the Target class
module Xcode
  class Project < Xcode::Object
    attr_reader :path, :project, :root
    attr_reader :targets
    
    def initialize(path)
      @path = Pathname.new(path).realpath.to_s
      fail "#{path} is not a directory\n" unless File.directory?(@path)

      plist_file = path + "/project.pbxproj"
      fail "no project file in #{path}\n" unless File.exist?(plist_file)
      @project = Plist::parse_xml(`plutil -convert xml1 -o - "#{plist_file}"`)
        
      @objects = {}
      @dict_by_identifier = @project['objects']
      root_identifier = @project['rootObject']
      @root = @dict_by_identifier[root_identifier]
        
      fail "doesn't look like the xcodeproj I expect\n" unless @root['isa'] == 'PBXProject'

      # Not sure this is useful, but being a subclass of Xcode::Object might let us use path caching
      super(self, @root, @project)
      @objects[root_identifier] = self # So we can look ourselves up in resolvepath()
      
      # Build map of object to containing group
      @containingGroup = {}
      @dict_by_identifier.each {|k,v|
        if ['PBXGroup', 'PBXVariantGroup'].index(v['isa'])
          v['children'].each {|ch|
            @containingGroup[ch.to_s] = k;
          }
        end
      }
      @containingGroup[@root['mainGroup'].to_s] = root_identifier

      # Build source tree map
      @sourceTrees = {'SOURCE_ROOT' => File.dirname(@path)}

      @targets = []
      @root['targets'].each {|targetID|
        @targets << self.get(targetID, Xcode::Target)
      }

    end

    # Return an object with the indicated key, optionally requiring it be one of the indicated classes
    def get(key, *allowedClasses)
      obj = @objects[key]
      return obj if obj
        
      dict = @dict_by_identifier[key]
      fail "No object with id '#{key}'!" unless dict
        
      actualClassName = dict['isa']
      fail "Class #{actualClassName} doesn't have prefix 'PBX' or 'XC'" unless (actualClassName.index("PBX") == 0 || actualClassName.index("XC") == 0)
        
      actualClass = Kernel.const_get("Xcode::#{actualClassName}")
      fail "No class #{actualClass} found" unless actualClass
        
      if allowedClasses
        unless allowedClasses.detect {|cls| actualClass == cls || actualClass < cls}
          fail "Expected subclass of one of #{allowedClasses.join(", ")}, but got #{actualClass}"
        end
      end
      
      obj = actualClass.new(self, key, dict)
      fail unless obj.identifier == key
      @objects[key] = obj
      obj
    end


    def resolvepath(key, resolve_variables = true)
      @pathCache ||= {}
        
      cached = @pathCache[key]
      return cached if cached

      obj = get(key, Xcode::PBXFileReference, Xcode::PBXVariantGroup, Xcode::PBXGroup, Xcode::PBXProject, Xcode::PBXReferenceProxy)
      return @sourceTrees['SOURCE_ROOT'] if obj == self

      sourceTree = obj.dict['sourceTree']

      if ENV['DEVELOPER_DIR'].nil?
        ENV['DEVELOPER_DIR'] = `xcode-select -print-path`.chomp
      end
      variables = ['DEVELOPER_DIR', 'BUILT_PRODUCTS_DIR', 'DEVELOPER_DIR', 'SDKROOT', 'DERIVED_FILE_DIR', 'PROJECT_DERIVED_FILE_DIR']
      
      case sourceTree
      when '<group>'
        groupID = @containingGroup[key.to_s]
        fail "no group contains child ref #{key}, died" unless groupID
        base = resolvepath(groupID)
      when '<absolute>'
        base = '/';
      else
        if variables.index(sourceTree)
          if resolve_variables
            base = ENV[sourceTree]
            fail "#{sourceTree} not specified in environment, but referenced by found file" unless base
          else
            base = "$#{sourceTree}"
          end
        else
          base = @sourceTrees[sourceTree.to_s]
        end
        fail "Unsupported source tree #{sourceTree}" unless base
      end

      path = obj.path
      if !path || path == ""
        path = base
      else
        path = Pathname.new("#{base}/#{path}").cleanpath.to_s
      end

      @pathCache[key] = path
      return path;
    end

    # Calls a block for each item that is in the sidebar (groups and file references)
    def each_item(&block)
      root_group = get(@root['mainGroup'].to_s, Xcode::PBXGroup)
      root_group.each_item(&block)
    end
    
    # Calls a block for each build file in the target, passing the build file id, build file plist and file ref id and file ref plist
    # Might want to add more classes to make this less crazy
    def each_file_in_target(target, &block)
      target.build_phases.each {|phase|
        phase.files.each {|buildFile|
          buildFile.file_references.each {|fileRef|
            block.call(buildFile, fileRef)
          }
        }
      }
    end
    
    def target_product_name(target)
      product_name = nil
      target.configuration_list.configurations.each {|config|
        # We assume the product name isn't set in the base configuration. Probably isn't, but it *could* be set there.
        settings = config.dict['buildSettings']
        configs_name = target.name
        if settings
          configs_name = settings['PRODUCT_NAME'] || configs_name
        end
            
        if product_name.nil?
          product_name = configs_name
        else
          fail "Different configurations have different product names!" unless product_name == configs_name
        end
      }
      return product_name
    end
    
  end
  
  class PBXProject < Project; end
end
