## [Unreleased]

## [0.2.6] - 2024-08-21

- Implement list healing so that existing lists can be fixed up when implementing `positioned` or if the list somehow gets corrupted.
- Tidy up Advisory Lock code.

## [0.2.5] - 2024-08-10

- Implemented composite primary key support. Thanks @jackozi for the original PR and the nudge to get this done!

## [0.2.4] - 2024-07-31

- Avoid unnecessary SQL queries when the position hasn't changed.

## [0.2.3] - 2024-07-06

- Advisory Lock can now be optionally turned off via `advisory_lock: false` on your `positioned` call. See the README for more details. Advisory Lock remains on by default. Thanks @joaomarcos96!

## [0.2.2] - 2024-05-17

- When destroying a positioned item, first move it out of the way (position = 0) then contract the scope. Do this before destruction. Moving the item out of the way memoizes its original position to cope with the case where multiple items are destroyed with `destroy_all` as they'll have their position column cached. Thanks @james-reading for the report.

## [0.2.1] - 2024-04-08

- Fetch the adapter_name from #connection_db_config (@tijn)
- Use `quote_table_name_for_assignment` in `update_all` calls to guard against reserved word column names.

## [0.2.0] - 2024-03-12

- Add an Advisory Lock to ensure isolation for the entirety of the create, update, and destroy cycles.
- Add SQLite Advisory Lock support using a file lock.

## [0.1.7] - 2024-03-06

- Separated the Concern that is included into ActiveRecord::Base into its own submodule so that Mechanisms isn't also included.
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
