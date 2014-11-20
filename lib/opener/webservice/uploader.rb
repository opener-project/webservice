module Opener
  module Webservice
    ##
    # Class for uploading KAF documents to Amazon S3.
    #
    class Uploader
      ##
      # Uploads the given KAF document.
      #
      # @param [String] identifier
      # @param [String] document
      # @param [Hash] metadata description
      #
      # @return [AWS::S3::S3Object]
      #
      def upload(identifier, document, metadata = {})
        object = create(
          "#{identifier}.xml",
          document,
          :metadata     => metadata,
          :content_type => 'application/xml'
        )

        return object
      end

      ##
      # @param [Array] args
      # @return [AWS::S3::S3Object]
      #
      def create(*args)
        return bucket.objects.create(*args)
      end

      ##
      # @return [AWS::S3.new]
      #
      def s3
        return @s3 ||= AWS::S3.new
      end

      ##
      # @return [AWS::S3::Bucket]
      #
      def bucket
        return @bucket ||= s3.buckets[Configuration.output_bucket]
      end
    end # Uploader
  end # Daemons
end # Opener
