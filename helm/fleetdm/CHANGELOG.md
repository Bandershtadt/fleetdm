# Changelog

All notable changes to this Helm chart will be documented in this file.

## [0.2.0] - 2025-10-07

### Changed - BREAKING CHANGES
- **MySQL**: Converted from Deployment to StatefulSet for guaranteed data persistence
- **Redis**: Converted from Deployment to StatefulSet for guaranteed data persistence
- Both MySQL and Redis services are now headless services (`clusterIP: None`)
- Removed standalone PVC resources - now using volumeClaimTemplates in StatefulSets

### Added
- StatefulSet ensures stable pod identity and guaranteed PVC binding
- No data loss on pod redeployment or rolling updates
- Maintainers field in Chart.yaml

### Fixed
- Database initialization hook weight adjusted to run after MySQL is ready
- Hook deletion policy changed to `hook-succeeded,hook-failed` for better debugging

### Migration Notes
If upgrading from 0.1.x to 0.2.0:
1. **IMPORTANT**: Backup your data before upgrading
2. Uninstall the old release: `helm uninstall fleetdm -n fleetdm`
3. Manually delete old PVCs if you want a fresh start
4. Install the new version: `helm install fleetdm ./helm/fleetdm -n fleetdm`

The StatefulSet will create new PVCs with names like `data-fleetdm-mysql-0` and `data-fleetdm-redis-0`.

## [0.1.1] - 2025-10-07

### Changed
- Updated FleetDM to version 4.55.0
- Improved resource limits and requests
- Enhanced documentation

## [0.1.0] - 2025-10-07

### Added
- Initial release with FleetDM, MySQL, and Redis
- Basic Helm chart structure
- Deployment-based architecture
- Persistent storage support
- Database initialization job
- Comprehensive testing setup

