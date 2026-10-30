# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Encodes record ids for use as a URL path segment. Rails routes treat "."
    # as a format separator, and worker ids (host names) and queue names may
    # contain dots, so dots are percent-encoded (and so "%" itself).
    module Param
      module_function

      def encode(id)
        id.to_s.gsub("%", "%25").gsub(".", "%2E")
      end

      def decode(param)
        param.to_s.gsub("%2E", ".").gsub("%25", "%")
      end
    end
  end
end
