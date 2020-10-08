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
      @uri = get_uri(params[:url])
      @url_type = params[:url]
      @recursive = true?(params[:recursive])
      @skip_products = true?(params[:skip_products])
      @categories = Hash.new()
    end

    def start
      save_main_categories_info
      search(@uri.to_s)

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

    def add_category(category_name, url)
      @categories = @categories.merge({"#{category_name}" => {url: url, products: []}})
    end

    def get_category_name(page)
      nodes = query_get_elements(page, "//li[@class='breadcrumb-item']").to_a

      case nodes.size
      when 0 then
        'ALL'
      when 1
        words = query_get_elements(nodes.pop, './span').text.split(' ') ## Убрать дублирование!
        words.slice!(1..words.size).join('->')
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

      page = get_nok(url)
      category_name = get_category_name(page)
      puts "Захожу на страницу по ссылке: #{url}"

      add_category(category_name, url) unless @categories.include?(category_name)

      if @recursive
        categories = get_categories(page)
        links = categories.map do |nod|
          @uri.path = get_value(nod, './a/@href')
          @uri.to_s
        end
        links.each { |link| search(link) }
      end

      # extract_products_page(category_name, page) unless @skip_products
      extract_products(@uri.path) unless @skip_products
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

    def save_main_categories_info
      response = Curl.get('https://api.av.by/offer-types/cars/filters/main/init') do |curl|
        add_headers(curl)
      end
      @main_categories_info = JSON(response.body_str)['seo']['links']
    end

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

    def extract_products(path)
      post_body = {
          "page" => 1,
          "properties" =>
              [{"name" => "brands",
                "property" => 5,
                "value" => [[{"name" => "brand", "value" => 1444}]]},
               {"name" => "price_currency", "value" => 2}]}

      http = Curl.post('https://api.av.by/offer-types/cars/filters/main/apply', post_body.to_json) do |curl|
        add_headers(curl)
      end

      result = JSON http.body_str

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