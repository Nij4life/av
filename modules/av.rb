require 'pry'
require_relative 'helper'
require 'curb'
require 'json'

module AV
  class AV_parser
    @@debag = true
    @@url_root = 'https://cars.av.by'
    @@url_api_landings = 'https://api.av.by/offer-types/cars/landings' #  тоже удалить наверное ???
    include Helper
    attr_reader :result

    def initialize(params)
      # @uri = get_uri(params[:url])
      @start_url = params[:url]
      @url_type = params[:url_type]
      @recursive = true?(params[:recursive])
      @skip_products = true?(params[:skip_products])
      @categories = Hash.new()
      @main_categories_info = []
    end

    def start
      #  Наверное тут нужно и разделить качать все категории или это подкатегория !

      # save_main_categories_info
      # test

      search(@start_url)

      @categories.each_pair {|name, value| puts "#{name} : #{value[:products].size} products"}

      #page = get_nok(@uri.to_s)
      #category_name = get_category_name(page)
      #
      #el = query_get_elements(page, "//script")
      ##add_category(category_name, url) unless @categories.include?(category_name)
      #binding.pry
    end

    private

    def get_products(node)
      product_nodes = query_get_elements(node, '//div[contains(@class, "listing-wrap")]/div[contains(@class, "listing-item")]').to_a
      product_nodes.map { |node| get_info(node) }
    end

    def get_info(node)
      info = {}
      info['url'] = get_value(node, './/div[@class="listing-item-image-in"]/a/@href')
      info['img'] = get_value(node, './/div[@class="listing-item-image-in"]/a/img/@src')
      info['year'] = get_value(node, './/div[@class="listing-item-wrap"]/div[@class="listing-item-price"]/span')
      info['price'] = get_value(node, './/div[@class="listing-item-wrap"]/div[@class="listing-item-price"]/small')
      info['city'] = get_value(node, './/div[@class="listing-item-wrap"]/div[@class="listing-item-price"]/div/p')
      info['name'] = get_value(node, './/div[@class="listing-item-wrap"]//div[@class="listing-item-title"]//h4/a')
      info['description'] = get_value(node, './/div[@class="listing-item-wrap"]//div[@class="listing-item-desc"]')

      info
    end

    def get_categories(nok)
      query_get_elements(nok, ".//li[@class='catalog__item']").to_a
    end

    def add_category(category_name, landing_result)
      str = landing_result["initialValue"]
      id_list = str.scan(/=\d+/).map { |id| id[/\d+/] }

      part_request_body = id_list.size == 1 ?
                              [{"name" => "brand", "value" => id_list[0]}] :
                              [{"name" => "brand", "value" => id_list[0]}, {"name" => "model", "value" => id_list[1]}]

      category = {'part_request_body': part_request_body, products: []}
      @categories = @categories.merge({"#{category_name}" => category})
      category
    end

    def get_category_name(page)
      nodes = query_get_elements(page, "//li[@class='breadcrumb-item']").to_a

      case nodes.size
      when 0 then
        'ALL'
        #when 1
        #  words = query_get_elements(nodes.pop, './span').text.split(' ') ## Убрать дублирование!
        #  words.slice!(1..words.size).join('->')
        #  binding.pry
      else
        words = query_get_elements(nodes.pop, './span').text.split(' ')
        words.slice!(1..words.size).join('->')
      end.downcase
    end

    def search(url)
      unless url[@@url_root]
        puts "\n Страница не содержит корневого url!\n"
        return false
      end

      uri = get_uri(url)

      # ВОЗМОЖНО запускать тут landing, если это не ALL
      landing_result = testM(uri.path)

      page = get_nok(url)
      category_name = get_category_name(page) # можно брать из uri.path !

      puts "Захожу на страницу по ссылке: #{url} ; категория: #{category_name}"

      category = add_category(category_name, landing_result) unless @categories.include?(category_name)

      if @recursive
        links = landing_result['seo']['links'].map { |cat| cat['url'] }
        # return if links.empty? # Вроде нет разницы ... ?!
        links.each { |link| search(link) }
      end


      extract_products(landing_result, category) unless @skip_products
      # extract_products_page(category_name, page) unless @skip_products
      # extract_products(category_name) unless @skip_products
      # update_categories(category_name)

    end

    def update_categories(category_name)
      # Записывать в базу
    end

    def get_next_pages(current_page)
      pages = []
      page = current_page

      while page
        link = get_value(page, './/li[@class="pages-arrows-item"]/a[text()="Следующая страница →"]/@href')
        break unless link
        page = get_nok(link)
        pages.push(page)
      end

      pages
    end

    # def save_main_categories_info
    #   response = Curl.get('https://api.av.by/offer-types/cars/filters/main/init') do |curl|
    #     add_headers(curl)
    #   end
    #   @main_categories_info = JSON(response.body_str)['seo']['links']
    # end

    def add_headers(obj)
      obj.headers['Accept'] = '*/*'
      # curl.headers['Accept-Encoding'] = 'gzip, deflate, br'
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

    def testM(path)
      response = Curl.get("https://api.av.by/offer-types/cars/landings#{path}") do |curl|
        add_headers(curl)
      end
      JSON response.body_str
      # ["blocks", "count", "pageCount", "page", "adverts", "sorting", "currentSorting", "advertsPerPage", "initialValue", "extended", "seo"]
    end

    def create_post_body(page_number, part_request_body)
      post_body = {
          "page" => page_number,
          "properties" => [
              {"name" => "brands", "property" => 5, "value" => [part_request_body]},
              {"name" => "price_currency", "value" => 2}
          ]
      }
    end

    def send_new_request(page_number, part_request_body)
      post_body = create_post_body(page_number, part_request_body)

      http = Curl.post('https://api.av.by/offer-types/cars/filters/main/apply', post_body.to_json) do |curl|
        add_headers(curl)
      end

      JSON http.body_str
    end

    def extract_products(landing_result, category)
      page = landing_result['page']
      all_pages = landing_result['pageCount']
      products = [*landing_result['adverts']]

      (page+1..all_pages).step do |i|
        res = send_new_request(i, category[:part_request_body])
        products += res['adverts']
      end

      category[:products] = products
      # binding.pry
    end
  end

  # скачивает продукты со этой и следующих страниц в категории
  def extract_products_page(category_name, page)
    products = []
    products += get_products(page).to_a

    while page
      link = get_value(page, './/li[@class="pages-arrows-item"]/a[text()="Следующая страница →"]/@href')
      break unless link
      page = get_nok(link)
      products += get_products(page).to_a
    end
    @categories[category_name][:products] = products.flatten # Проверить точно ли он нужен !!!!!!!!!!!!!!!!!!!!
    puts "#{category_name}: extract #{@categories[category_name][:products].size} products"
  end
end

__END__

'https://api.av.by/offer-types/cars/landings' # get

ЕслиНаГлавнойНажатьПоказатьВсе => отправляетья запрос 'https://api.av.by/offer-types/cars/filters/main/init' # https://cars.av.by/filter
  стандартно приходит 25 обьявлений adverts, block, page, pageCount, seo ...   фильтр - актуальные (ЭТО НЕ просто НОВЫЕ!!)

  любое изменение фильтра => отправляетья запрос    https://api.av.by/offer-types/cars/filters/main/apply
     но в body  отправляю страницу и id сортировки

  Если перехожу на брэнд  -->> отправляетья запрос     'https://api.av.by/offer-types/cars/landings/brand' # напр brand == acura
    изменение фильтра по нему  -->> отправляетья запрос   https://api.av.by/offer-types/cars/filters/main/apply
    но в боди добавляеться  -->>    {name: "brands", property: 5, value: [[{name: "brand", value: 1444}]]}
    value: 1444  = это потому что это id брэнда acura, на котором я был.