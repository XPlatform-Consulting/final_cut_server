# FinalCutServer

A Library and Utilities for interacting with Final Cut Server

## Installation

Add this line to your application's Gemfile:

    gem 'final_cut_server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install final_cut_server

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( https://github.com/XPlatform-Consulting/final_cut_server/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## Utilities

### Generate Asset Metadata CSV (bin/generate_asset_metadata_csv.rb)

#### Overview

  Takes in a production id or an asset id as arguments and outputs the asset metadata to a csv file.

#### Usage

    Usage: generate_asset_metadata_csv [options]
        --[no-]all-assets            Outputs metadata for all assets
        --production-id ID           A production id of a production to output the asset information for.
        --asset-id ID                An asset id of an asset to output
        --csv-file-output FILEPATH   The csv file path.
                                     The file will be created if it doesn't exist or will overwrite an existing file
        --log-level INTEGER          Logging Level. 0 = DEBUG. Default = 1