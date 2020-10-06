require 'pry'
require_relative 'helper'

module AV
  class AV_parser
    @@debag = true
    include Helper
    attr_reader :result

    def initialize(params)
      @url = params[:url]
      @url_type = params[:url]
      @recursive = true?(params[:recursive])
      @skip_products = true?(params[:skip_products])
      @categories = Hash.new()
    end

    def start
      search(@url)
      total = 0
      @categories.values.each {|el| total += el[:products].size}
      puts "Total count products: #{total}"
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

    def get_category(nok)
      query_get_elements(nok, "//ul[@class='brandslist']/li").to_a
    end

    def add_category(category_name, url)
      @categories = @categories.merge({"#{category_name}" => {url: url, products: []} })
      #puts "@categories.size: #{@categories.size}"
    end

    def get_category_name(page)
      nodes = query_get_elements(page, "//ul[@class='breadcrumb-list']/li").to_a
      size = nodes.size <=> 2
      case size
      when -1 then ''
      when 0 then nodes[1].text.strip.downcase
      else
        nodes.shift
        nodes[0] = query_get_elements(nodes[0], ".//span[@class='text-capitalize']")
        nodes.map {|el| el.text.strip}.join(' -> ')
        end.downcase
    end

    def search(url)
      return false unless url['https://cars.av.by']
      puts "Захожу на страницу по ссылке: #{url}"
      page = get_nok(url)
      category_name = get_category_name(page)

      add_category(category_name, url) unless @categories.include?(category_name)

      if @recursive
        categories = get_category(page)
        links = categories.map {|nod| get_value(nod, './a/@href') }
        links.each {|link| search(link) }
      end

      extract_products_page(category_name, page) unless @skip_products
      update_categories(category_name)

    end

    def update_categories(category_name)
      #puts "category_name #{category_name} can be update" # Вместо вывода записывать в базу
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
end