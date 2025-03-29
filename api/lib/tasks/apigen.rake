# -*- coding: utf-8 -*-

# frozen_string_literal: true

require_relative "../../config/boot"
require "apigen"

namespace :apigen do
  task generate_json: [:environment] do |_t, args|
    with_loaded_documentation do
      out = ENV["OUT"] || Rails.root.join("gen")
      _generate_swagger_using_args(args, out)
    end
  end

  def _generate_swagger_using_args(args, out)
    doc = Apigen.app.generate_swagger_json
    _generate_swagger_json_page(out, doc)
  end

  def _generate_swagger_json_page(file_base, doc)
    FileUtils.mkdir_p(file_base) unless File.exist?(file_base)

    path = Pathname.new("#{file_base}/schema_swagger.json")
    File.open(path, "w") { |file| file.write(JSON.pretty_generate(doc)) }

    path
  end

  def with_loaded_documentation
    Apigen.app.reload
    yield
  end

  task merge_swagger: [:environment] do
    file_base = ENV["OUT"] || Rails.root.join("gen")

    file1 = Pathname.new("#{file_base}/schema_swagger.json")
    file2 = Pathname.new("#{file_base}/gitmono.json")
    output_file = Pathname.new("#{file_base}/merged_swagger.json")

    # 读取两个 JSON 文件
    swagger1 = JSON.parse(File.read(file1))
    swagger2 = JSON.parse(File.read(file2))

    # 合并 paths
    merged_paths = swagger1.fetch("paths", {}).merge(swagger2.fetch("paths", {}))

    # 合并 components
    merged_components = deep_merge(swagger1.fetch("components", {}), swagger2.fetch("components", {}))

    # 生成合并后的 Swagger JSON
    merged_swagger = {
      "openapi" => "3.0.0",
      "info" => swagger1.fetch("info", {}),
      "paths" => merged_paths,
      "components" => merged_components,
    }

    # 写入合并后的 JSON 文件
    File.open(output_file, "w") do |f|
      f.write(JSON.pretty_generate(merged_swagger))
    end

    puts "Swagger JSON 文件合并完成，已生成 #{output_file} 🎉"
  end

  def deep_merge(hash1, hash2)
    hash1.merge(hash2) do |key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val) # 递归合并子项
      else
        new_val
      end
    end
  end
end
