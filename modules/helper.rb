require 'curb'
require 'nokogiri'

module Helper
  def true?(obj)
    obj.to_s.downcase == "true"
  end

  def get_nok(url)
    html = Curl.get(url)
    Nokogiri::HTML(html.body_str)
    # puts nok.errors
  end

  def query_get_elements(node, query)
    node.xpath(query)
  end

  def get_value(nok, path)
    str = nok.xpath(path).text.gsub(/\s+/, ' ').strip
    str.empty? ? nil : str
  end

  def print_variants(arr)
    arr.each.with_index do |item, i|
      end_str = i == (arr.length - 1) ? '.' : ', '
      print item.to_s + end_str
      puts if (i+1) % 20 == 0
    end
    puts
  end

  # Научиться менять элементы и вставлять результаты в нужный node
  def result_to_html
    start_html = File.open('./html/index.html') { |file| file.read }

    File.open('./html/parser_result.html', 'w') do |file|
      file.write start_html
      @result.each { |hash|
        file.write "
    <li class='item'>
      <div><img class='item__image' src='#{hash['img']}' alt='image car'/></div>
      <ul class='item__info'>
        <li><span>more information:</span>  <a href='#{hash['url']}'>link</a></li>
        <li><span>model:</span>  #{hash['name']}</li>
        <li><span>year:</span>  #{hash['year']}</li>
        <li><span>price:</span>  #{hash['price']}$</li>
        <li><span>city:</span>  #{hash['city']}</li>
        <li><span>description:</span>  #{hash['description']}</li>
      </ul>
    </li>"
      }
      file.write '</ul>'
      file.write '</body>'
      file.write '</html>'

      return file
    end
    puts "\nРезультат сохранен в папке html в файл parser_result.html\n"
  end

end