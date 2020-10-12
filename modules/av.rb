require 'pry'
require_relative 'helper'
require 'curb'
require 'json'
require_relative 'errors'

module AV
  class AV_parser
    @@debag = true
    include Helper
    attr_reader :result

    def initialize(params)
      @start_url = params[:url]
      @url_type = params[:url_type]
      @recursive = true?(params[:recursive])
      @skip_products = true?(params[:skip_products])
      @categories = Hash.new()
      @main_categories_info = []
    end

    # ruby parser.rb -u https://cars.av.by/jeep/patrion -t categories -s false -r true
    # patrioN !! сделать rescue

    def start
      search(@start_url)
    end

    private

    def get_info(product)
      # products.keys => # [ "id", "version", "sellerName", "questionAllowed", "publishedAt", "refreshedAt", "locationName",
      # "shortLocationName",  "photos", "status", "publicStatus", "advertType", "properties", "description", "exchange",
      #  "top",  "highlight", "videoUrl", "videoUrlId", "publicUrl", "metaInfo", "renewedAt", "metadata", "price"]
      info = {}
      info['id'] = product['id']
      info['url'] = product['publicUrl']
      info['photos'] = product['photos'].map { |photo| photo['big']['url'] }
      info['year'] = product['properties'].select { |el| el['value'] if el['id'] == 6 }
      info['price'] = product['price']['usd'].values { |val| val }.join(': ')
      info['city'] = product['shortLocationName']
      info['name'] = product['properties'].select { |el| [2, 3, 4].include?(el['id']) }.map { |el| el['value'] }.join(' ')
      info['description'] = product['description']

      info
    end

    def add_category(category_name, response_category)
      str = response_category["initialValue"]
      id_list = str.scan(/=\d+/).map { |id| id[/\d+/] }

      part_request_body = id_list.size == 1 ?
                              [{"name" => "brand", "value" => id_list[0]}] :
                              [{"name" => "brand", "value" => id_list[0]}, {"name" => "model", "value" => id_list[1]}]

      category = {'part_request_body': part_request_body, products: []}
      @categories = @categories.merge({"#{category_name}" => category})
      category
    end

    def search(url)
      puts "Зашел на url: #{url}"
      uri = get_uri(url)
      category_name = uri.path.split('/').join('->')

      response_category = request_category_page(uri.path)

      category = add_category(category_name, response_category) unless @categories.include?(category_name)

      return if response_category['adverts'].empty? # Because do not somethings

      extract_products(response_category, category) unless @skip_products
      update_categories

      if @recursive
        links = response_category['seo']['links'].map { |cat| cat['url'] }
        # return if links.empty? # Вроде нет разницы ... ?!
        links.each { |link| search(link) }
      end
    end

    def update_categories
      # Записывать в базу
    end

    def add_headers(obj)
      obj.headers['Accept'] = '*/*'
      obj.headers['Accept-Encoding'] = 'deflate, br'
      obj.headers['Accept-Language'] = 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7'
      obj.headers['Connection'] = 'keep-alive'
      # curl.headers['Content-Length'] = '133'
      obj.headers['Content-Type'] = 'application/json'
      obj.headers['Host'] = 'api.av.by'
      obj.headers['Origin'] = 'https://cars.av.by'
      obj.headers['Referer'] = 'https://cars.av.by/'
      obj.headers['Sec-Fetch-Dest'] = 'empty'
      obj.headers['Sec-Fetch-Mode'] = 'cors'
      obj.headers['Sec-Fetch-Site'] = 'same-site'
      obj.headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36'
      obj.headers['x-device-type'] = 'web.desktop'
      #curl.verbose = true
      obj
    end

    def request_category_page(path)
      api_link = path.empty? ? 'https://api.av.by/offer-types/cars/filters/main/init' : "https://api.av.by/offer-types/cars/landings#{path}"

      JSON Curl.get(api_link) { |curl| add_headers(curl) }.body_str
      # response.keys => # ["blocks", "count", "pageCount", "page", "adverts", "sorting", "currentSorting", "advertsPerPage", "initialValue", "extended", "seo"]
    end

    def create_post_body(page_number, part_request_body)
      {   "page" => page_number,
          "properties" => [
              {"name" => "brands", "property" => 5, "value" => [part_request_body]},
              {"name" => "price_currency", "value" => 2}
          ]
      }
    end

    def send_new_request(page_number, part_request_body)
      post_body = create_post_body(page_number, part_request_body)

      JSON Curl.post('https://api.av.by/offer-types/cars/filters/main/apply', post_body.to_json) { |curl| add_headers(curl) }.body_str
    end

    def extract_products(response_category, category)
      products = [*response_category['adverts']]

      if response_category['pageCount'] > 1
        start_range = response_category['page'] + 1
        end_range = response_category['pageCount']

        (start_range..end_range).step do |i|
          products += send_new_request(i, category[:part_request_body])['adverts']
          # тут была странная ошибка. на audi 121 и выше стр. приходил result['adverts'] == []
        end
      end

      category[:products] = products.map { |product| get_info(product) }
      # puts "#{response_category['seo']['currentPage']['url']} : #{category[:products].size} products"
    end
  end
end
