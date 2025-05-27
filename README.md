# Foobar2000 Playlist File Search Tool

This PowerShell script is designed to help manage and process Foobar2000 `.m3u8` playlist files. It allows you to search for specific files across playlists and optionally replace file paths in playlists with new ones.

## Features

- **Search Mode**: Search for files in a source playlist and report their locations in other playlists.
- **Replace Mode**: Replace file paths in playlists based on a source and replacement playlist.

## Enhancements and optimizations

- **Unwanted Playlists Filtering**: Automatically exclude unwanted playlists from processing.
- **Environment Variable Support**: Use environment variables in the configuration file for dynamic paths.
- **Reverse Content Indexing**: The script builds a reverse index of playlist content for faster lookups, significantly optimizing search operations.
- **Progress Indicators**: Progress bars are displayed during indexing and search operations, providing real-time feedback to the user.
- **Error Handling**: The script includes robust error handling, such as verifying file selections and ensuring source and replacement playlists have matching line counts.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Foobar2000 `.m3u8` playlists
- A JSON configuration file (`config.json`)

## Installation

1. Clone or download this repository to your local machine.
2. Ensure PowerShell is installed and available in your system's PATH.
3. Configure the `config.json` file (see below for details).

## Configuration

The script uses a JSON configuration file (`config.json`) to define directories, file extensions, and other settings. Below is an example configuration:

```json
{
    "ListsDir": "C:\\Your list location",
    "ListsExt": "m3u8",
    "LogReportLoc": "$env:TEMP\\fb2k-search-files-report.txt",
    "LogMissingLoc": "$env:TEMP\\fb2k-search-files-missing.txt",
    "UnwantedLists": [
        "My first playlist.m3u8",
        "My second playlist.m3u8",
        "Don't forget to remove the .example from the extension in this file.m3u8"
    ]
}
```

### Configuration Fields

- **`ListsDir`**: The directory containing the `.m3u8` playlists to process. In foobar2000 you can export your playlists to a specific directory. A batch operation can be performed with the right click menu.
- **`ListsExt`**: The file extension of the playlists (default: `m3u8`).
- **`LogReportLoc`**: Path to the report file for search results.
- **`LogMissingLoc`**: Path to the log file for missing files.
- **`UnwantedLists`**: A list of playlist filenames to exclude from processing.

### Example Configuration Template

An example configuration file is provided as `copy.json.example`. Copy this file to `config.json` and customize it as needed.

```plaintext
copy.json.example -> config.json
```

## Usage

1. Open a PowerShell terminal.
2. Navigate to the directory containing the script.
3. Run the script:

   ```powershell
   .\fb2k-search-files.ps1
   ```

4. Follow the prompts to select a mode (`Search` or `Replace`) and provide the required playlists.

### Modes

- **Search Mode**:
  - Select a source playlist.
  - The script will search for the files in the source playlist across all other playlists and generate a report.

- **Replace Mode**:
  - Select a source playlist and a replacement playlist.
  - The script will replace file paths in playlists based on the mapping between the source and replacement playlists.
  - Both playlists should contain the same files for the replacement to work correctly.
  - A new subfolder named `_new-playlists` will be created within the `ListsDir` directory, containing only the playlists where replacements were successfully processed.

### Logs

- **Report File**: Contains the results of the search or replace operation.
- **Missing File Log**: Tracks any missing files encountered during processing.

## Notes

- Ensure that the `config.json` file is properly configured before running the script.
- The script will automatically exclude playlists listed in the `UnwantedLists` field of the configuration.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve the script.

## Thanks

- Foobar2000 developers (Peter Pawłowski and the rest of the community) for an unparralleled music playing experience.
- <https://patorjk.com/> for the ASCII art generator used in the script.
- PowerShell community for an invaluable scripting environment.
