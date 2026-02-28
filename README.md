# GitHub Action Operator

This project provides GitHub Action workflows for building and managing Gluten projects.

## Project Structure

- `.github/scripts/` - Build scripts
- `.github/workflows/` - GitHub Action workflows
- `.trae/` - Trae configuration

## Available Workflows

- `build_gluten_arm.yml` - Builds Gluten for ARM architecture
  - **Trigger**: Push to main or master branches
  - **Runner**: Ubuntu latest
  - **Steps**:
    1. Checkout current repo
    2. Set up QEMU for multi-arch support
    3. Check Docker dependency
    4. Set up Docker Buildx
    5. Cache Docker layers
    6. Pull SWR public image
    7. Create local directories
    8. Start build container
    9. Pull code to container (Gluten, OmniOperator, libboundscheck, BoostKit_CI)
    10. Execute build script
    11. Copy artifact from container
    12. Upload artifacts
  - **Artifacts**: `gluten-artifacts-arm` (gluten.zip)

## Build Scripts

- `build_gluten.sh` - Script for building Gluten

## Usage

To use the workflows in this repository:

1. Fork this repository
2. Modify the workflows as needed
3. Trigger the workflows via GitHub Actions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
