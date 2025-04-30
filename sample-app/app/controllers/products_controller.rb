class ProductsController < ApplicationController
  def index
    products = case ENV['SERVICE_VERSION']
    when 'v2.0'
      v2_products
    when 'v3.0'
      v3_products
    else
      v0_products
    end

    results = products.map do |product|
      {
        product: product.name,
        price: product.price,
        description: product.description,
        category: product.category.name,
      }
    end

    # 改善ポイント: 重い処理を行うメソッドが呼び出されている
    (1..3).each do |n|
      method_sample(n)
    end

    render json: results
  end

  def show
    product = Product.includes(:category).find(params[:id])

    # IDで一見一貫性がないように見えつつ処理時間やエラーを発生させるための処理
    hv = Digest::SHA256.hexdigest(params[:id])
    v = hv.reverse[0, 2].to_i(16)
    # vは0〜255になる。特定範囲の間はエラーを発生させる

    OpenTelemetry.tracer_provider.tracer('product_controller').in_span(
      'product info loader',
      kind: :server
    ) do |span|
      span.set_attribute(OpenTelemetry::SemanticConventions::Trace::CODE_FUNCTION, "info_loader")
      span.set_attribute('product.id', params[:id])
      span.set_attribute('product.name', product.name)
      span.set_attribute('product.categoryname', product.category.name)

      sleep((v % 10 + 1) * 0.25)
      if v < 40
        sleep(2)
        raise("Timeout to get product information")
      end
    end
    render json: format_product(product)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  end

  private
    def format_product(product)
      {
        product: product.name,
        price: product.price,
        description: product.description,
        category: product.category.name
      }
    end

  def v0_products
      Product.all.sample(100)
    end

    def v2_products
      # 改善1: product を 1 つオブジェクトにするたびに category を取得している N+1 問題を解決
      # https://railsguides.jp/active_record_querying.html#%E9%96%A2%E9%80%A3%E4%BB%98%E3%81%91%E3%82%92eager-loading%E3%81%99%E3%82%8B
      Product.includes(:category).all.sample(100)
    end

    def v3_products
      # 改善2: product を取得した後に 100 件に絞っているが、これを SQL で一発で取得するようにする
      # https://railsguides.jp/active_record_querying.html#limit%E3%81%A8offset
      Product.includes(:category).limit(100).order('RAND()')
    end

    def method_sample(n = 10)
      OpenTelemetry.tracer_provider.tracer('product_controller').in_span(
        'method_sample',
        kind: :server
      ) do |span|
        if ENV['SERVICE_VERSION'] && ENV['SERVICE_VERSION'] > 'v1'
          n = 0
        end
          sleep(n)
        span.set_attribute(OpenTelemetry::SemanticConventions::Trace::CODE_FUNCTION, __method__.to_s)
        span.set_attribute('sleep.time', n)

        if ENV['SERVICE_VERSION'] && ENV['SERVICE_VERSION'] > 'v1'
          if n > 5
            raise "Sleep time is too long: #{n}"
          end
        else
          # 改善ポイント: エラーが発生する
          if n > 2
            raise "Sleep time is too long: #{n}"
          end
        end
      end
    end
end
