# Opener Webservice

This Gem makes it possible for OpeNER components to be used as a webservice.
Input can be passed directly or using an URL, the latter allows for greater data
sizes to be processed. Webservices can be chained together using callback URLs,
each passing its output to the next callback. Output can either be passed
directly, or as a URL pointing to a document in Amazon S3.

## Usage

Create an executable file `bin/<component>-server`, for example
`bin/language-identifier-server`, with the following content:

    #!/usr/bin/env ruby

    require 'opener/webservice'

    parser = Opener::Webservice::OptionParser.new(
      'opener-<component>',
      File.expand_path('../../config.ru', __FILE__)
    )

    parser.run

Replace `<component>` with the name of the component. For example, for the
language identifier this would result in the following:

    #!/usr/bin/env ruby

    require 'opener/webservice'

    parser = Opener::Webservice::OptionParser.new(
      'opener-language-identifier',
      File.expand_path('../../config.ru', __FILE__)
    )

    parser.run

Next, create a `config.ru` file in the root directory of the component. It
should have the following content:

    require File.expand_path('../lib/opener/<component>', __FILE__)
    require File.expand_path('../lib/opener/<component>/server', __FILE__)

    run Opener::<constant>::Server

Replace `<component>` with the component name, replace `<constant>` with the
corresponding constant. For example, for the language identifier:

    require File.expand_path('../lib/opener/language_identifier', __FILE__)
    require File.expand_path('../lib/opener/language_identifier/server', __FILE__)

    run Opener::LanguageIdentifier::Server

## Input

To submit data, send a POST request to the root URL of a webservice. The request
body can either be a set of POST fields, or a JSON object. In both cases the
following fields can be set:

* `input`: direct input to process
* `input_url`: a URL to a document to download and process
* `callbacks`: an array of callback URLs to send output to
* `error_callback`: a URL to send errors to
* `request_id`: a custom request ID/identifier to associate with the document
* `metadata`: an arbitrary metadata object to associate with a document, only
  supported when using JSON input as POST fields can't represent key/values.

Any other parameters are ignored _but_ passed along to the next callback (if
any).

To use JSON input, set the `Content-Type` header to `application/json` when
submitting data.

If no callback URLs are specified the data is processed synchronously, the
response will be whatever output the underlying component returned (usually
KAF).

When using a callback URL the response will be a JSON object containing:

* `request_id`: the generated (or manually specified) request ID/identifier
* `output_url`: the URL that will contain the end output after all callbacks
  have been processed

If an error occurs the output URL will _not_ contain the document, instead a
POST request is executed using the URL in the `error_callback` field. This URL
receives the following parameters:

* `request_id`: The ID of the request/document that failed
* `error`: the error message

## Requirements

* A supported Ruby version (see below)
* Amazon S3 (only when one wants to store ouput in S3)
* libarchive (for running the tests and such), on Debian/Ubuntu based systems
  this can be installed using `sudo apt-get install libarchive-dev`

The following Ruby versions are supported:

| Ruby     | Required      | Recommended |
|:---------|:--------------|:------------|
| MRI      | >= 1.9.3      | >= 2.1.4    |
| Rubinius | >= 2.2        | >= 2.3.0    |
| JRuby    | >= 1.7        | >= 1.7.16   |

Note that various components use JRuby, thus they won't work on MRI and
Rubinius.

## S3 Support

To enable storing of output on Amazon S3, specify the `--bucket` option when
running the CLI. Also make sure that the following environment variables are
set:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`

If you're running this daemon on an EC2 instance then the first two environment
variables will be set automatically if the instance has an associated IAM
profile. The `AWS_REGION` variable must _always_ be set.

Output files are named `<identifier>.xml` where `<identifier>` is the unique
identifier of the document. The content type of these documents is set to
`application/xml`.  Metadata associated with the job (as specified in the
`metadata` field) is saved as metadata of the S3 object.

The S3 URLs are only valid for a limited time (currently 1 hour) so callbacks
must ensure they can process the input within that time limit.

To use custom identifiers for documents, specify a unique value in the
`request_id` parameter when submitting data. Existing documents using the same
identifier will be _overwritten_, so make sure your identifiers are truly
unique. Default identifiers are generated using Ruby's `SecureRandom.hex`
method.

## Monitoring

Components using this Gem can measure performance using New Relic and report
errors using Rollbar. To support this the following two environment variables
must be set:

* `NEWRELIC_TOKEN`
* `ROLLBAR_TOKEN`

For New Relic the application names will be `opener-<component>` where
`<component>` is the component name, as defined by a component itself. If one of
these environment variables is not set the corresponding feature is disabled.
