# frozen_string_literal: true

require "net/http"
require "json"

module Availability
  module Adapters
    class BaseAdapter
      TIMEOUT_SECONDS = 15

      def fetch_slots(venue, search)
        raise NotImplementedError
      end

      private

      def get_json(url, headers: {})
        response = request(url, headers:)
        raise AdapterError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end

      def get_text(url, headers: {})
        response = request(url, headers:)
        raise AdapterError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def post_json(url, body:, headers: {})
        response = request(url, method: :post, body:, headers:)
        raise AdapterError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end

      def post_text(url, body:, headers: {})
        response = request(url, method: :post, body:, headers:)
        raise AdapterError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def request(url, method: :get, body: nil, headers: {})
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = TIMEOUT_SECONDS
        http.read_timeout = TIMEOUT_SECONDS

        request_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
        request = request_class.new(uri)
        headers.each { |key, value| request[key] = value }
        request.body = body if body

        http.request(request)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise TimeoutError, "Request timed out"
      rescue SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
        raise AdapterError, e.message
      end
    end
  end
end
