## [Unreleased]

## [0.1.7] - 2024-03-06

- Seperated the Concern that is included into ActiveRecord::Base into its own submodule so that Mechanisms isn't also included.
- Added the RelativePosition Struct and documentation to make it easier to supply relative positions via form helpers.

## [0.1.6] - 2024-03-05

- Allow the position to be passed as a JSON object so that we can pass in complex positions from the browser more easily.

## [0.1.5] - 2024-03-04

- Allow empty strings to represent nil for the purposes of solidifying a position

## [0.1.4] - 2024-03-04

- Fix bug relating to relative position hash coming from Rails being a Hash With Indifferent Access

## [0.1.3] - 2024-03-04

- Internal refactoring of Mechanisms for clarity
- Additional unit testing of Mechanisms
- Added additional Ruby and Rails versions to the Github Actions matrix

## [0.1.2] - 2024-02-29

- Fix a bug related to the scope changing with an explicitly set position value that is the same as the original position.

## [0.1.1] - 2024-02-25

- Fix issues with STI based models

## [0.1.0] - 2024-02-24

- Initial release
