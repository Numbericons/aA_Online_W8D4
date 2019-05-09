require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    # debugger
    @data ||= DBConnection.execute2(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL

    @data.first.map {|ele| ele.to_sym}
  end

  def self.finalize!
    self.columns.each do |column|
      define_method("#{column}=") do |value|
        self.attributes[column] = value
      end

      define_method("#{column}") do
        self.attributes[column]
      end
    end
  end

  def self.table_name=(table_name)
    @table = table_name
  end

  def self.table_name
    @table ||= self.to_s.tableize
  end

  def self.all
    hash = DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL
    self.parse_all(hash)
  end
  
  def self.parse_all(results)
    results.map do |hash|
      self.new(hash)
    end
  end

  def self.find(id)
    new_obj = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{self.table_name}
      WHERE id = ?
      LIMIT 1
    SQL
    self.new(new_obj.first) unless new_obj.first.nil?
  end

  def initialize(params = {})
    params.each do |k,v|
      k = k.to_sym
      raise "unknown attribute '#{k}'" unless self.class.columns.include?(k)
      self.send("#{k}=",v)
    end
    
  end

  def attributes
    @attributes ||= Hash.new
  end

  def attribute_values 
    # @attributes.values
    self.class.columns.map do |el|
      el = self.send(el.to_sym)
    end
  end

  def insert
    # debugger
    cols = self.class.columns
    col_names = cols[1..-1].join(",")
    vals = attribute_values[1..-1]
    q_marks = (["?"] * ((cols.length) - 1)).join(",")
    DBConnection.execute(<<-SQL, *vals)
      INSERT INTO
        #{self.class.table_name} (#{col_names}) #cats (name, foreign_key)
      VALUES
        (#{q_marks})
      SQL
    self.id = DBConnection.last_insert_row_id
    #need to get id from above to set instance id
  end

  def update
    
    colvals = self.class.columns.map {|el| "#{el} = ?"}.join(",") #maybe remove joins for splat below
    vals = attribute_values
    # debugger
    #{id: self.id,}
    DBConnection.execute(<<-SQL, *vals, self.id) 
      UPDATE
        #{self.class.table_name}
      SET
        #{colvals}    
      WHERE
        id = ?
      SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
