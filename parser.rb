require_relative 'modules/av'
require 'choice'

#Choice

# Хотелось бы передавать boolean в new. Но Choice принимает [string, integer, float, symbol]
Choice.options do
  header ''
  header 'Specific options:'

  option :url do
    short '-u'
    long '--url=URL'
    desc 'This is the address of the page we need'
    default 'https://av.by/'
  end

  option :url_type do
    short '-t'
    long '--url_type=URL_TYPE'
    desc 'This is the information type from page which we need. (categories or products)'
    default 'categories'
  end

  option :recursive do
    short '-r'
    long '--recursive=RECURSIVE'
    desc 'You need recursive descent for subcategories. (true or false)'
    default 'false'
  end

  option :skip_products do
    short '-s'
    long '--skip_products=SKIP_PRODUCTS'
    desc 'Skip collecting product data. (true or false)'
    default 'true'
  end

  separator ''
  separator 'Common options: '
  separator '-u or --url   # Url адрес нужной нам категории'
  separator '-t or --url_type   # Тип переданного url адреса (category or product)'
  separator '-r or --recursive   # Опция рекурсивного обхода дерева категорий (true or false)'
  separator '-s or --skip_products   # Опция для указания, пропустить ли скачивание продуктов (true or false)'
  separator 'По умолчанию при запуске:  # -u https://cars.av.by/ -t category -r false -s false'
  separator 'Examples: '
  separator 'ruby parser.rb -r true   # Собрать все дерево категорий'
  separator 'ruby parser.rb -r true -s false   # Собрать все дерево категорий и сохранить продукты'
  separator 'ruby parser.rb -u https://cars.av.by/acura   # Обновить категорию acura'
  separator 'ruby parser.rb -u https://cars.av.by/acura -r true   # Собрать дерево подкатегорий для acura'
  separator 'ruby parser.rb -u https://cars.av.by/acura -r true -s false   # Собрать дерево подкатегорий для acura и сохранить продукты'
  separator 'ruby parser.rb -u https://cars.av.by/acura/mdx -s false   # Обновить категорию acura -> mdx и скачать с нее продукты'

  option :help do
    short '-h'
    long '--help'
    desc 'Show this message'
  end
end

puts Choice.choices[:help]

av = AV::AV_parser.new(Choice.choices)

av.search