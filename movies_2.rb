class Ratings
  attr_accessor :person_array # an array of all persons in the data
  attr_accessor :movie_array # an array of all movies in the data
  attr_accessor :person_hash # hashes that keep track of person/movie ID to created movie/person objects
  attr_accessor :movie_hash
#  @movie_sorted # this is the array that will be used to store movies sorted by popularity - don't want to create it multiple times in different calls of popularity_list

  def load_data(filename)
    #base_name = filename.to_s + ".data"
    #test_name = filename.to_s + ".test" # this won't be needed since only one class should be responsible for 1 file?
    file_base = open(filename, "r")
    @person_array = Array.new # initialize them all
    @movie_array = Array.new
    @person_hash = Hash.new
    @movie_hash = Hash.new
    @movie_sorted = Array.new
    file_base.each do |line|
      split_line = line.split() # split the line, cast them all as ints
      name = split_line[0].to_i
      movie = split_line[1].to_i
      rating = split_line[2].to_i
      if @person_hash[name] == nil # if the hash doesn't exist, make it
        @person_hash[name] = Person.new(name)
        @person_array.push(@person_hash[name])
      end
      person_object = @person_hash[name] # grab the object, add the necessary data, move on
      person_object.add_rating(movie, rating)
      if @movie_hash[movie] == nil
        @movie_hash[movie] = Movie.new(movie)
        @movie_array.push(@movie_hash[movie])
      end
      movie_object = @movie_hash[movie]
      movie_object.add_rating(rating, name)
    end
  end

  def popularity(movie) #popularity is defined as how many people rate the movie - even bad press is still press!
    movie_object = @movie_hash[movie]
    return movie_object.number_of_ratings
  end

  def similarity(user1, user2) # similarity will depend on how many common movies they "like" (3* or better rating) and the total number of unique movies they like
    if !user1.is_a?(Person)
      user1 = @person_hash[user1] # this way, if someone likes the same 10 movies as someone else, but between them they also like 30 other unique movies
    end
    if !user2.is_a?(Person)
      user2 = @person_hash[user2] # they will be less similar than a pair who like the same 10 movies and only like 5 other unique movies
    end
    similar_likes = (user1.liked_movies & user2.liked_movies).length # (I have no clue how good of a system that is)
    total_likes = user1.liked_movies.length + user2.liked_movies.length - similar_likes
    similarity_rating = (similar_likes*1.0)/(total_likes)
    return similarity_rating
  end

  def most_similar(u)
    if !u.is_a?(Person)
      u = @person_hash[u]
    end
    @person_array.each do |other_person|
      other_person.most_recent_similarity = similarity(u, other_person) # set each person's similarity variable to their similarity with this user
    end
    @person_array.sort! {|a,b| a.most_recent_similarity <=> b.most_recent_similarity} # sort the person array by this value
    number_to_return = 10 # this will determine how many similar users to return, to be changed at user's will
    u.top_ten_similar = (@person_array.last(number_to_return+1))[0..-2]
    return (@person_array.last(number_to_return+1))[0..-2] # this will just remove the last person - obviously the person with most similar tastes to someone is themself! so don't include that in the list
  end

  def predict(user, movie)
    if !user.is_a?(Person) # get the person object associated
      user = @person_hash[user]
    end
    if movie.is_a?(Movie) # BUT since the person object doesn't store movie objects, we need the movie ID, not the object
      movie = movie.name
    end
    if user.movies_with_ratings[movie] != nil # if he rated it, predict that!
      puts user.movies_with_ratings[movie]
      return user.movies_with_ratings[movie]
    end
    if user.movies.length == user.liked_movies.length || user.liked_movies.length*1.0/user.movies.length > 0.8 # if he liked all or most the movies he saw, guess that he'll like this one
      return 4
    end
    if user.liked_movies.length == 0 || user.liked_movies.length*1.0/user.movies.length < 0.25 # if he liked none or close to none, guess that he'll hate it
      return 2
    end
    # easy stuff is over, now we'll check similar people
    if user.top_ten_similar.empty?
      most_similar(user) # generate its top 10 similar list to be used
    end
    (user.top_ten_similar).each do |simuser|
      if simuser.movies_with_ratings[movie] != nil
        return simuser.movies_with_ratings[movie]
      end
    end
    return 4 # if we managed to pass all these and no similar user rated the movie, guess 4 (hey, the webpage said it was a good guess!)
  end

end

class Movie # movie object class, keeps track of all ratings and how many
  attr_accessor :name
  attr_accessor :rated_by
  attr_accessor :ratings
  attr_accessor :number_of_ratings

  def initialize(name)
    @name = name
    @ratings = Array.new
    @rated_by = Array.new
    @number_of_ratings = 0
  end

  def add_rating(rating, user)
    @ratings.push(rating)
    @rated_by.push(user)
    @number_of_ratings += 1
  end
end


class Person # person class, keeps a hash of movie to the preson's ratings, all the movies they've rated, and what movies they liked
  attr_accessor :name
  attr_accessor :movies_with_ratings
  attr_accessor :movies
  attr_accessor :liked_movies
  attr_accessor :most_recent_similarity # this variable is used in similarity functions - this will allow me to sort the persons array by similarity rating
  attr_accessor :top_ten_similar # similarity list

  def initialize(name)
    @name = name
    @movies_with_ratings = Hash.new()
    @movies = Array.new
    @liked_movies = Array.new
    @top_ten_similar = Array.new
  end

  def add_rating(movie, rating)
    @movies_with_ratings[movie] = rating
    @movies.push(movie)
    if rating >= 4
      @liked_movies.push(movie)
  end
end

class Validator
  attr_accessor :formatted_ratings_predictions

  def initialize(base, testing)
    @base_ratings = base
    @test_ratings = testing
    @formatted_ratings_predictions = Array.new
  end

  def validate
    test_movies_array = @test_ratings.movie_array
    predicted_difference = Array.new # create an array to store all the differences between predicted vs real ratings, to be used for data analysis - space heavy!
    (test_movies_array).each do |movie|
      (movie.rated_by).each do |user|
        prediction = @base_ratings.predict(user, movie)
        actual = (@test_ratings.person_hash[user]).movies_with_ratings[movie.name]
        prediction_set = [user, movie.name, actual, prediction]
        @formatted_ratings_predictions.push(prediction_set)
        predicted_difference.push(prediction - actual)
      end
    end
    return predicted_difference
  end
end


class Control

  def initialize(base_set, test_set)
    base_ratings = Ratings.new
    test_ratings = Ratings.new
    base_ratings.load_data(base_set)
    test_ratings.load_data(test_set)
    @validator = Validator.new(base_ratings, test_ratings)
  end

  def run_predictions
    @prediction_differences = @validator.validate
  end

  def mean
    if(@mean == nil)
      sum = @prediction_differences.reduce(0){|sum, n| sum + n.abs} # since we care about distance from the prediction and not the direction, we use absolute value
      length = @prediction_differences.length
      @mean = sum*1.0/length
    end
    return @mean
  end

  def stdev
    if(@stdev == nil)
      if (@mean == nil)
        self.mean
      end
      square_minus_mean = @prediction_differences.map{|x| (x.abs - @mean) * (x.abs - @mean)}.reduce(:+)
      @stdev = Math.sqrt(square_minus_mean/(@prediction_differences.length - 1)) # sample, not population stdev
    end
    return @stdev
  end

  def rms
    if(@rms == nil)
      sum_in_square = @prediction_differences.map{|x| x * x}.reduce(:+)
      @rms = sum_in_square/prediction_differences.length
    end
    return @rms
  end

  def to_a
    return @validator.formatted_ratings_predictions
  end
  
end


test = Control.new("u1.base", "u1.test")
test.run_predictions
puts test.mean
puts test.stdev

end
