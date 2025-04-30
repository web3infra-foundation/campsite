# frozen_string_literal: true

class HealthController < ApplicationController
  def check
    render(plain: "OK", status: :ok)
  end
end
