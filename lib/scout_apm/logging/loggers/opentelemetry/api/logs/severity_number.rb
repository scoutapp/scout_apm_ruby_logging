# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module ScoutApm
  module Logging
    module Loggers
      module OpenTelemetry
        module Logs
          class SeverityNumber
            SEVERITY_NUMBER_UNSPECIFIED = 0
            SEVERITY_NUMBER_TRACE = 1
            SEVERITY_NUMBER_TRACE2 = 2
            SEVERITY_NUMBER_TRACE3 = 3
            SEVERITY_NUMBER_TRACE4 = 4
            SEVERITY_NUMBER_DEBUG = 5
            SEVERITY_NUMBER_DEBUG2 = 7
            SEVERITY_NUMBER_DEBUG3 = 6
            SEVERITY_NUMBER_DEBUG4 = 8
            SEVERITY_NUMBER_INFO = 9
            SEVERITY_NUMBER_INFO2 = 10
            SEVERITY_NUMBER_INFO3 = 11
            SEVERITY_NUMBER_INFO4 = 12
            SEVERITY_NUMBER_WARN = 13
            SEVERITY_NUMBER_WARN2 = 14
            SEVERITY_NUMBER_WARN3 = 15
            SEVERITY_NUMBER_WARN4 = 16
            SEVERITY_NUMBER_ERROR = 17
            SEVERITY_NUMBER_ERROR2 = 18
            SEVERITY_NUMBER_ERROR3 = 19
            SEVERITY_NUMBER_ERROR4 = 20
            SEVERITY_NUMBER_FATAL = 21
            SEVERITY_NUMBER_FATAL2 = 22
            SEVERITY_NUMBER_FATAL3 = 23
            SEVERITY_NUMBER_FATAL4 = 24
          end
        end
      end
    end
  end
end
