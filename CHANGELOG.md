# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.09] - 2025-02-21

### Added

- new functionality which allows to break processing and continue
  for this case additional directory is created with processed data.
  this data can be automatically reused when script is run again with -continue option

## Changed

- modified tags processed from SQL Database to include more information

## [1.08] - 2025-02-21

### Added

- Update item "Kind" from App Service Plans to specify OS type of the service - app,linux means linux, other means windows

## [1.07] - 2025-02-19

### Added

- New item "ManagedBy" which allows to see which resource is a parent of the resource

### Changed

- Consolidate tags into one resource "Tags". Tags values are encapsulated in JSON format


## [1.06] - 2024-10-21

### Added

- add missing Azure ResourceTypes

### Changed

- Remove showing tags with Debug option
- Fix reporting FQDN for VMs

## [1.05] - 2024-10-21

### Changed

- change case of the tags to lower to reduce duplicates
- exclude tags starting with `NMW-` from the report (Azure Virtual Desktop)
- added prefix 'zTags' to the tags to put them at the end
- sorting metadata in the report

## [1.04] - 2024-10-07

### Added

- Gather resources from all available subscriptions
- Gather Tags from resources
- Gather addional data from resources

### Changed

- move to the SiiPoland Repository

## [1.03] - 2020-09-29

### Added

- Tag added whether the resource can be moved to different resource group or a subscription

## [1.02] - 2020-07-07

### Added

- Fix reporting SKU, Add reporting VM Disk size

## [1.01] - 2018-07-28

### Added

- Reporting SKU parameters

## [1.00] - 2018-05-15

### Added

- Initial version
