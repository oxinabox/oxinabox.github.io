---
layout: default
title: "Optimizing your diet with JuMP"
tags:
    - julia
    - jupyter-notebook
---
I've been wanting to do a [JuMP](https://github.com/JuliaOpt/JuMP.jl) blog post for a while.
JuMP is a Julia mathematical programing library.
It is to an extent a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) for describing constrained optimisation problems.

A while ago, a friend came to me who was looking to get "buff",
what he wanted to do, was maximise his protein intake, while maintaining a generally healthy diet.
He wanted to know what foods he should be eating.
To devise a diet.

If one thinks about this,
this is actually a [Linear Programming](https://en.wikipedia.org/wiki/Linear_programming) problem -- constrained linear optimisation.
The variables are how much of each food to eat,
and the contraints are around making sure you have enough (but not too much) of all the essential vitamins and minerals.

Note: this is a bit of fun, in absolutely no way do I recommend using the diets the code I am about to show off generates.
I am in no way qualified to be giving dietry or medical advice, etc.
But this is a great way to play around with optimisation.
<!--more-->

So lets get started:
Humans need nutrients, food contains nutrients do humans eat food.
We could go down the path of consuming nutrient soup directly, but it is considered [unfun](https://en.wikipedia.org/wiki/Soylent_(meal_replacement)).
People are also dubious of it ability to provide a complete diet due to sciences incomplete knowledge of exactly what trace minerals we might need.
The same criticism kinda occurs here too.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using JuMP
using GLPKMathProgInterface
{% endhighlight %}
</div>

We are going to load up JuMP.
We are using [GLPK](https://www.gnu.org/software/glpk/) as the solver.
We actually have many options for the [solver](http://www.juliaopt.org/JuMP.jl/0.18/installation.html#getting-solvers)
Last time I checked (which was a while back), GLPK was the only free solver that supported callbacks with Mixed Integer Programming.
We are not requiring that so our choices are much wider.
I find the commercial Gurobi solver to be orders of magnitude faster the GLPK (for MIP problems); and they are nice enough to give away liscense to accademics, but I do not have it installed on this computer, so GLPK will do.

So when defining a diet the goal is the choose to eat certain amounts of different foods,
such that when totalled all your nutrient needs are taken care off.

So the first thing we are going to need to know is what are the nutrient contents of various foods we can buy.
A table breaking that down has been produced by Food Standards Australia.
Someone might like to try and get this working with
[USDA Food Composition Databases](https://ndb.nal.usda.gov/ndb/),
which is likely a bit more comprehensive.

We define a data dependency of this program on that database using [DataDeps.jl](https://github.com/oxinabox/DataDeps.jl):

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using DataDeps
register(DataDep(
    "AUSNUT Food Nutrient Database",
    """
        Website: http://www.foodstandards.gov.au/science/monitoringnutrients/
        Excel spreedsheet of food nutrient values prepared by Food Standard Australia New Zealand, between 2011 and 2013.
    """,
    "http://www.foodstandards.gov.au/science/monitoringnutrients/ausnut/Documents/8b.%20AUSNUT%202011-13%20AHS%20Food%20Nutrient%20Database.xls",
     "4bac90de8ab2673a2f9b19f0be4c822aac1832ed8314117666e5464ed57cb544"
        ;
    post_fetch_method = (fn)->mv(fn, "database.xls")
));
{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using ExcelFiles, DataFrames

const nutrients = DataFrame(load(datadep"AUSNUT Food Nutrient Database/database.xls", "Food Nutrient Database"))
nutrients[1:4,:]
{% endhighlight %}
</div>

**Output:**




<table class="data-frame"><thead><tr><th></th><th>Food ID</th><th>Survey ID</th><th>Food Name</th><th>Survey flag</th><th>Energy, with dietary fibre (kJ)</th><th>Energy, without dietary fibre (kJ)</th><th>Moisture (g)</th><th>Protein (g)</th><th>Total fat (g)</th><th>Available carbohydrates, with sugar alcohols (g)</th><th>Available carbohydrates, without sugar alcohol (g)</th><th>Starch (g)</th><th>Total sugars (g)</th><th>Added sugars (g)</th><th>Free sugars (g)</th><th>Dietary fibre (g)</th><th>Alcohol (g)</th><th>Ash (g)</th><th>Preformed vitamin A (retinol) (µg)</th><th>Beta-carotene (µg)</th><th>Provitamin A (b-carotene equivalents) (µg)</th><th>Vitamin A retinol equivalents (µg)</th><th>Thiamin (B1) (mg)</th><th>Riboflavin (B2) (mg)</th><th>Niacin (B3) (mg)</th><th>Niacin derived equivalents (mg)</th><th>Folate, natural  (µg)</th><th>Folic acid  (µg)</th><th>Total Folates  (µg)</th><th>Dietary folate equivalents  (µg)</th><th>Vitamin B6 (mg)</th><th>Vitamin B12  (µg)</th><th>Vitamin C (mg)</th><th>Alpha-tocopherol (mg)</th><th>Vitamin E (mg)</th><th>Calcium (Ca) (mg)</th><th>Iodine (I) (µg)</th><th>Iron (Fe) (mg)</th><th>Magnesium (Mg) (mg)</th><th>Phosphorus (P) (mg)</th><th>Potassium (K) (mg)</th><th>Selenium (Se) (µg)</th><th>Sodium (Na) (mg)</th><th>Zinc (Zn) (mg)</th><th>Caffeine (mg)</th><th>Cholesterol (mg)</th><th>Tryptophan (mg)</th><th>Total saturated fat (g)</th><th>Total monounsaturated fat (g)</th><th>Total polyunsaturated fat (g)</th><th>Linoleic acid (g)</th><th>Alpha-linolenic acid (g)</th><th>C20:5w3 Eicosapentaenoic (mg)</th><th>C22:5w3 Docosapentaenoic (mg)</th><th>C22:6w3 Docosahexaenoic (mg)</th><th>Total long chain omega 3 fatty acids (mg)</th><th>Total trans fatty acids (mg)</th></tr></thead><tbody><tr><th>1</th><td>10F40019</td><td>3.1103e7</td><td>Beef, extract, bonox</td><td>missing</td><td>401.0</td><td>401.0</td><td>56.6</td><td>16.6</td><td>0.2</td><td>6.5</td><td>6.5</td><td>6.5</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>19.8</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.36</td><td>0.27</td><td>5.4</td><td>7.71</td><td>6.0</td><td>0.0</td><td>6.0</td><td>6.0</td><td>0.23</td><td>8.0</td><td>0.0</td><td>0.6</td><td>0.6</td><td>110.0</td><td>9.1</td><td>2.0</td><td>60.0</td><td>360.0</td><td>690.0</td><td>4.0</td><td>6660.0</td><td>1.5</td><td>0.0</td><td>0.0</td><td>136.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>2</th><td>13A12001</td><td>3.1302e7</td><td>Basil, dried</td><td>missing</td><td>1079.0</td><td>774.0</td><td>10.0</td><td>18.2</td><td>5.5</td><td>15.5</td><td>15.5</td><td>15.5</td><td>0.0</td><td>0.0</td><td>0.0</td><td>38.2</td><td>0.0</td><td>15.5</td><td>0.0</td><td>27135.0</td><td>27334.0</td><td>4556.0</td><td>0.327</td><td>1.9</td><td>7.79</td><td>11.62</td><td>436.0</td><td>0.0</td><td>436.0</td><td>436.0</td><td>1.34</td><td>0.0</td><td>337.0</td><td>6.9</td><td>6.91</td><td>2091.0</td><td>57.0</td><td>16.36</td><td>273.0</td><td>291.0</td><td>3818.0</td><td>2.7</td><td>118.0</td><td>17.27</td><td>0.0</td><td>0.0</td><td>225.0</td><td>2.36</td><td>1.4</td><td>0.61</td><td>0.26</td><td>0.34</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>3</th><td>10E10113</td><td>3.1302e7</td><td>Cardamom, seeds, ground</td><td>missing</td><td>1333.0</td><td>1109.0</td><td>8.3</td><td>10.8</td><td>6.7</td><td>40.5</td><td>40.5</td><td>31.0</td><td>9.5</td><td>0.0</td><td>0.0</td><td>28.0</td><td>0.0</td><td>5.8</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.198</td><td>0.182</td><td>1.1</td><td>3.74</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.23</td><td>0.0</td><td>21.0</td><td>0.5</td><td>0.5</td><td>383.0</td><td>0.5</td><td>13.97</td><td>229.0</td><td>178.0</td><td>1119.0</td><td>0.5</td><td>18.0</td><td>7.47</td><td>0.0</td><td>0.0</td><td>155.0</td><td>2.2</td><td>2.81</td><td>1.39</td><td>1.0</td><td>0.39</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>4</th><td>10E10098</td><td>3.1302e7</td><td>Chilli (chili) powder</td><td>missing</td><td>1441.0</td><td>1167.0</td><td>7.8</td><td>12.3</td><td>16.8</td><td>20.5</td><td>20.5</td><td>10.4</td><td>10.1</td><td>0.0</td><td>0.0</td><td>34.2</td><td>0.0</td><td>11.8</td><td>0.0</td><td>15000.0</td><td>17790.0</td><td>2965.0</td><td>0.35</td><td>0.79</td><td>7.9</td><td>8.98</td><td>9.0</td><td>0.0</td><td>9.0</td><td>9.0</td><td>2.09</td><td>0.0</td><td>0.0</td><td>38.1</td><td>38.14</td><td>278.0</td><td>0.5</td><td>14.3</td><td>170.0</td><td>303.0</td><td>1920.0</td><td>20.4</td><td>1010.0</td><td>2.7</td><td>0.0</td><td>0.0</td><td>64.0</td><td>2.41</td><td>3.15</td><td>7.85</td><td>7.32</td><td>0.52</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr></tbody></table>



If you talk a look at that table is should quickly become apparent that everything is for 100g of that foodstuffs.
So basical dataframes usage lets us look up a column:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
nutrients[:, Symbol("Protein (g)")] 
{% endhighlight %}
</div>

**Output:**




    5740-element Array{Float64,1}:
     16.6
     18.2
     10.8
     12.3
     14.1
      4.2
      6.0
     13.0
     18.4
     12.7
     23.0
      8.5
     11.1
      ⋮  
      3.3
      3.2
      2.2
      2.6
      0.9
      1.3
      1.3
      1.2
      1.2
      1.2
      1.1
      1.0



If I wanted to know how much Protein was in  100g of Beef extract (the first food in the list).

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
nutrients[1, Symbol("Protein (g)")]
{% endhighlight %}
</div>

**Output:**




    16.6



If I wanted to know how much Protein was in 100g of Beef extract (the first food in the list) and 150g of Cardamom seeds (the 3rd item). 
That would be:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
1*nutrients[1, Symbol("Protein (g)")] + 1.5*nutrients[3, Symbol("Protein (g)")]
{% endhighlight %}
</div>

**Output:**




    32.800000000000004



If I had a big list (a vector) of how much of each item I was having (in units of 100g),
I could write it using the [dot product](https://en.wikipedia.org/wiki/Dot_product).

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
x = zeros(size(nutrients,1))
x[1] = 1   # 100g Beef extract
x[3] = 1.5 # 150g Cardamom seeds
nutrients[:, Symbol("Protein (g)")] ⋅ x
{% endhighlight %}
</div>

**Output:**




    32.800000000000004



Our "diet" is just that, it is a long list specifying how much of each food is to be eaten each day.
(It is hopefully a sparse list).
So we can use that to express our constraints.

I'm going to define a function to construct such as diet as a JuMP variable.
The syntax
`@variable(m, x[1:10], lowerbound=0)`
says: within the model `m` to declare a new variable `x` that is a vector indexed between 1 and 10,
and it comes with the built in constraint that is its greater than `0`.

A JuMP model is basically the representation of the system of contraints and the optimisation function etc;
so when we declare a new constraint or variable we always pass in the model to specify which system we are working with.
(You might be building multiple systems at once.)

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using JuMP
function new_diet(solver = GLPKSolverLP())
    m = Model(solver= solver)
    @variable(m, diet[1:size(nutrients,1)], lowerbound=0)
    m, diet 
end
{% endhighlight %}
</div>

**Output:**




    new_diet (generic function with 2 methods)



The syntax:
```
@constraints(m, begin
    5 <= x
    3 <= y <= 10
end)
```
Says to that in model `m` with declare that the variable `x` must be 5 or greater, and that variable `y` must be between 3 and 10 (inclusive).

Our constraints are going to be a bit more complicated than that.
In particular I am going to use the dot product we expressed before to calcuate the total intake of a particular nutrient.
To do that I will define a closure over the variable `diet`,
which I will call `intake`. One might need to spend a little time looking at this.


I spent some time digging up some constraints on what nutrients people need.
You can see the references below in the comments.

We are going to use them to define our basic constraints before considering what we are working with.
We'ld define a function to add those constraints to our model.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function total_intake(nutrient_name, diet)
    nutrients[:, Symbol(nutrient_name)] ⋅ diet
end

function basic_nutrient_requirements(m::Model, diet, weight = 62) # average human is 62 kg
    intake(nutrient_name) = total_intake(nutrient_name, diet) 
    # ^ closure over the diet given as an argument
        
    @constraints(m, begin
        70 <= intake("Protein (g)") 
        70 <= intake("Total fat (g)") 
        24 <= intake("Total saturated fat (g)") 
        90 <= intake("Total sugars (g)") 
        intake("Alcohol (g)") <= 100
        310 <= intake("Available carbohydrates, with sugar alcohols (g)") 
        intake("Sodium (Na) (mg)") <= 2300 # Heart Council
        intake("Caffeine (mg)") <= 400
        25 <=intake("Dietary fibre (g)") 
        24 <= intake("Total trans fatty acids (mg)") 
        25 <= intake("Vitamin A retinol equivalents (µg)") <= 900
        1.2 <= intake("Thiamin (B1) (mg)") 
        400 <= intake("Dietary folate equivalents  (µg)") 
        1000 <= intake("Folic acid  (µg)") # https://ods.od.nih.gov/factsheets/Folate-HealthProfessional/
        75 <= intake("Vitamin C (mg)") <= 2000 ##https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        95 <= intake("Iodine (I) (µg)") <=1100 ##https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        6 <= intake("Iron (Fe) (mg)") <= 45 # #https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        330 <= intake("Magnesium (Mg) (mg)") 
        580 <= intake("Phosphorus (P) (mg)") <= 4000 #https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        4700 <= intake("Potassium (K) (mg)") 
        800 <= intake("Calcium (Ca) (mg)") <= 2500 #https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        3.5*weight <= intake("Tryptophan (mg)") <= 0.5*weight*1600 #0.5 * LD50 https://books.google.com.au/books?id=he7LBQAAQBAJ&pg=PA210&lpg=PA210&dq=Tryptophan+LD-50&source=bl&ots=yzi5Hx7hM2&sig=sd78LGAnavIwtT5AP-L4fzsFLZM&hl=en&sa=X&ved=0ahUKEwjJhcjFn6rQAhUKkJQKHbw6AiwQ6AEIMTAE#v=onepage&q=Tryptophan%20LD-50&f=false
                                                #http://www.livestrong.com/article/541961-how-much-tryptophan-per-day/
        17 <= intake("Linoleic acid (g)") 

        45 <= intake("Selenium (Se) (µg)") <= 400 #https://en.wikipedia.org/wiki/Dietary_Reference_Intake
        11 <= intake("Zinc (Zn) (mg)") <= 40 #https://en.wikipedia.org/wiki/Dietary_Reference_Intake
            
            
        6 <= intake("Vitamin E (mg)") <= 1_200    #https://www.livestrong.com/article/465706-vitamin-e-overdose-levels/
            
        1.3 <= intake("Vitamin B6 (mg)") <= 300  #https://www.news-medical.net/health/Can-You-Take-Too-Much-Vitamin-B.aspx
        2.4 <= intake("Vitamin B12  (µg)")   #https://www.news-medical.net/health/Can-You-Take-Too-Much-Vitamin-B.aspx
            
    end)
    
end


{% endhighlight %}
</div>

**Output:**




    basic_nutrient_requirements (generic function with 2 methods)



Note this list is not comprehensive, (or necessarily entirely correct).
I started with a fairly small list of constraints then added to it based on the weirdnesses of the diets that were being generated.
For example, some of my initial diets generated included something like _"Drink 4L coffee per day"_,
so I added a constrain against consuming more than 400 mg of caffine.

Feel encourage to mess around, and change or add constraints (like we will below).
The snippit below is useful to search for the column name if you don't know how it is specified -- the table is a bit large to do that by hand.
I'd recommend against ever trying to display the full model: JuMP  will display it mathematically,
and in JuPyTer even will render it as LaTeX.
But it is utterly huge:
the system so far has 25 constraints, each referring to 5740 variables

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
filter(x->contains(x, "Vitamin B"), String.(collect(names(nutrients))))
{% endhighlight %}
</div>

**Output:**




    2-element Array{String,1}:
     "Vitamin B6 (mg)"  
     "Vitamin B12  (µg)"



The last thing we will need before we can start getting solutions is a way to view the result.
`getvalue(diet)` will return the solve value (once solved).
But since out diet is defines is a vector with 5740 entries, just showing it doesn't get us much.
So I define an function to print it out neatly

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function show_diet(diet)
    for ii in eachindex(diet)
        amount = getvalue(diet[ii])
        if amount > 0
            name = nutrients[ii, Symbol("Food Name")]
            grams = round(Int, 100amount) # amount is expressed in units of 100 grams
            display_as = grams < 1  ? ">0" : string(grams) #Make things that are "0.001 grams" show as ">0 grams"
            println(lpad(display_as, 5, " "), " grams \t", name)
        end
    end
end
{% endhighlight %}
</div>

**Output:**




    show_diet (generic function with 1 method)



## Diet 1: Minimize Energy, with only basic nutritional constraints

So now we are ready to go.
We set up out system of constraints, 
add an objective to minimze the total energy (I guess for weight loss),
and solve it.
It is a linear programming problem.
It is actually underconstrained, so almost certainly has multiple optimal solutions.
But that is fine we just want one.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);

@objective(m, Min,  total_intake("Energy, with dietary fibre (kJ)" , diet))
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
    5 grams 	Cream of tartar, dry powder
   16 grams 	Fibre
   10 grams 	Folic acid
   >0 grams 	Thiamin
   >0 grams 	Vitamin C
 2353 grams 	Tea, regular, white, brewed from leaf or teabags, with cows milk not further defined
32011 grams 	Water, rainwater or tank water
  148 grams 	Milk, almond, fluid
 2848 grams 	Milk & water, skim cow's milk & tap water
   48 grams 	Fat, dairy blend or margarine spread, not further defined
   12 grams 	Oil, safflower
    1 grams 	Fat, solid, vegetable oil based
   10 grams 	Shortening, commercial, vegetable fat (for coatings, creams, icings, confectionery & fillings)
  228 grams 	Lolly, non-mint flavours, intense sweetened
   42 grams 	Cabbage, pickled, canned, drained
  263 grams 	Mixed vegetables, Asian greens, boiled, microwaved or steamed, drained

{% endhighlight %}
</div>

So looking at that result it is fairly ok.
A buch of basically supplements, plus some oils, and vegetables.
That makes up your vitamins and minerals I'ld say.
The packet of "Lolly, non-mint flavours, intense sweetened", makes up your carbs.

2 Problems:

Firstly, it is suggesting dringking 32L of water in a day.
Why is that? This is because water has basically no nutritional impact to our constraints,
so it can take almost any value.
To solve this, a simple trick is to add a small factor to out objective,
saying _"All other things being equal, a diet with less total mass, is better"_.
This can be done by adding a term  `+ 0.01sum(diet)`.
The 0.001 is small enough that it shouldn't impact the true objective much.

Secondly, it recommends drinking over 2 kg of tea, and 2 kg of watered milk.
That is pretty boring,
so lets add a constraint that one shouldn't ever consume >500gram of the same item.


## Diet 2: Minimize Energy, improved

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);

@constraint(m, diet .<= 5) # nothing more than 500g

@objective(m, Min,  
    total_intake("Energy, with dietary fibre (kJ)", diet) + 0.01sum(diet)
)
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
  192 grams 	Stock, liquid, all flavours (except fish), homemade from basic ingredients
   10 grams 	Folic acid
   >0 grams 	Thiamin
  500 grams 	Coffee, from ground coffee beans, with regular fat coffee whitener
  500 grams 	Coffee, macchiato, from ground coffee beans, decaffeinated, with regular fat cows milk
   39 grams 	Coffee, long black style, from ground coffee beans, double shot, without milk
  500 grams 	Tea, regular, white, brewed from leaf or teabags, with cows milk not further defined
  500 grams 	Milk, almond, fluid
  468 grams 	Milk, cow, fluid, prepared from dry powder, regular fat, standard dilution
  500 grams 	Milk & water, reduced fat cow's milk & tap water
  500 grams 	Milk & water, skim cow's milk & tap water
   14 grams 	Oil, safflower
   61 grams 	Cumquat (kumquat), raw
   13 grams 	Coconut, milk, canned, not further defined
    5 grams 	Oyster, cooked, with or without added fat
  228 grams 	Lolly, non-mint flavours, intense sweetened
  425 grams 	Bok choy or choy sum, baked, roasted, fried, stir-fried, grilled or BBQ'd, no added fat
  119 grams 	Cabbage, white, baked, roasted, fried, stir-fried, grilled or BBQ'd, fat not further defined
   43 grams 	Cabbage, pickled, canned, drained

{% endhighlight %}
</div>

This is a bit better than before.
I particularly appreciate the handful of Cumquats and the half an oster.

Still rather high on Milk, since it has basically worked around the 500g limit, by using 3 different types of watered-down Milk.
Also that seems like a whole lot of coffee, even if some is decaff.
How much caffine is that?

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
total_intake("Caffeine (mg)", getvalue(diet))
{% endhighlight %}
</div>

**Output:**




    399.99999999999943



So it is right up against out boundary of <400g caffine per day.
This isn't surprising, since the optimal solution to a linear programming problem is somewhere on the edge of the feasible region.

I'm just not happy with the amount of liquid in this diet still though.


## Diet 4: Minimize Energy, improved, limit liquid portions

I think, I'ld just like my diet to be less than 5% liquid by mass.
After all I do drink water on my own.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);

@constraint(m, diet .<= 5) # nothing more than 500g
@constraint(m, total_intake("Moisture (g)", diet) <= 0.25sum(diet)*100) # Less than 25% liquid

@objective(m, Min,  
    total_intake("Energy, with dietary fibre (kJ)", diet) + 0.01sum(diet)
)
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
  500 grams 	Salt substitute, potassium chloride
    1 grams 	Salt, flavoured
  500 grams 	Cream of tartar, dry powder
    2 grams 	Caffeine
   13 grams 	Calcium
    8 grams 	Fibre
  500 grams 	Folic acid
    9 grams 	Iodine
  500 grams 	Thiamin
   19 grams 	Vitamin C
   12 grams 	Vitamin E
  124 grams 	Coffee, macchiato, from ground coffee beans, with skim cows milk
  144 grams 	Tea, regular, white, brewed from leaf or teabags, with cows milk not further defined
   19 grams 	Oil, safflower
    3 grams 	Shortening, commercial, vegetable fat (for coatings, creams, icings, confectionery & fillings)
  291 grams 	Octopus, cooked, with or without added fat
    2 grams 	Oyster, cooked, with or without added fat
  152 grams 	Bar, nougat & caramel centre, milk chocolate-coated
  217 grams 	Lolly, non-mint flavours, intense sweetened
  167 grams 	Bok choy or choy sum, baked, roasted, fried, stir-fried, grilled or BBQ'd, no added fat
  229 grams 	Mixed vegetables, Asian greens, stir-fried or fried, fat not further defined

{% endhighlight %}
</div>

mmmmmmmmmm, yum. Powdered suppliments.
For interest: a Pipi is a tiny Australian Molusc that lives in the sand.
As a child I would watch them wash up on the beach,  and try and grab then before the burrowed into the ground.
2grams would be about 1 of them, you could cook it with a lighter.

One thing that is going on here is that it is stocking up on powder's to bring the total moister portion down.
For example Thiamin  is B1 suppliments,
Apparently [you can't normally overdose on B1](https://www.livestrong.com/article/367247-vitamin-b1-overdose-symptoms/),
and so we have no containts on B1 intake, except the 500gram max.

## Diet 5: Minimize Energy, improved, ban liquids
What I really want to do is just remove items from the list that are basically liquids.
I could filter the list to remove anything with more than 96% liquid,
but actually that knocks out things like lettuce, but doesn't knock out all the varients milk.
More sensible is to just blacklist by name, and cross-ref with moisture.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function forbid_liquids(m::Model, diet, keywords=["milk", "drink", "Water", "Milk"])
    # not blocking lowercase "water" as that would block "Soup made with water"
    
    inds = keyword_using_inds = find(x->any(contains.(x, keywords)), nutrients[:, Symbol("Food Name")])
    high_moisture_inds =  find(x->x>50, nutrients[:, Symbol("Moisture (g)")])
    inds = intersect(keyword_using_inds, high_moisture_inds)
    #@show nutrients[inds, Symbol("Food Name")]
    @constraint(m, diet[inds] .== 0 ) # nothing more than 500g

end
{% endhighlight %}
</div>

**Output:**




    forbid_liquids (generic function with 2 methods)



**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);
forbid_liquids(m, diet)

@constraint(m, diet .<= 5) # nothing more than 500g

@objective(m, Min,  
    total_intake("Energy, with dietary fibre (kJ)", diet) + 0.01sum(diet)
)
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
  500 grams 	Stock, liquid, all flavours (except fish), homemade from basic ingredients
   87 grams 	Stock, liquid, fish, homemade from basic ingredients
    2 grams 	Cream of tartar, dry powder
   10 grams 	Folic acid
    1 grams 	Iodine
   >0 grams 	Thiamin
  500 grams 	Coffee, from ground coffee beans, with regular fat coffee whitener
   20 grams 	Oil, safflower
  118 grams 	Beef, rump steak, fully-trimmed, raw
   12 grams 	Lamb, easy carve shoulder, semi-trimmed, raw
    6 grams 	Goat, separable fat (composite), raw
    1 grams 	Nut, brazil, with or without skin, raw, unsalted
  136 grams 	Bar, nougat & caramel centre, milk chocolate-coated
  218 grams 	Lolly, non-mint flavours, intense sweetened
  500 grams 	Bok choy or choy sum, baked, roasted, fried, stir-fried, grilled or BBQ'd, no added fat
   73 grams 	Cabbage, white, baked, roasted, fried, stir-fried, grilled or BBQ'd, fat not further defined
   29 grams 	Mixed vegetables, Asian greens, stir-fried or fried, fat not further defined
   87 grams 	Mixed vegetables, Asian greens, boiled, microwaved or steamed, drained

{% endhighlight %}
</div>

I hope you enjoy your shashi slice of lamb and goat.

## Diet 6: Maximize protein 

So by friend trying to get buff, he wanted to maximize protein.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);


@objective(m, Max,  
    total_intake("Protein (g)", diet)
)
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
   10 grams 	Folic acid
    1 grams 	Vitamin C
  667 grams 	Flour, soya
24034 grams 	Lard
  800 grams 	Suet
  845 grams 	Amino acid or creatine powder
42752 grams 	Intense sweetener, containing aspartame, powdered formulation

{% endhighlight %}
</div>

Again, if we just want to maximize Protein, then the solution comes out rather silly.
It basically says eat as much protein containing food as you can until you hit one of the nutrient upper bounds.
Almost 25Kg, of Lard, over 42Kg of powerered sweetener.
It is kinda amazing that this is apparently hitting all the nutritonal requirements.


Obvious mistake is we forgot to bound the amount of energy.

## Diet 7: Maximize Protein with Energy Constraints
We could do the [Basal Metabolic Rate](https://en.wikipedia.org/wiki/Basal_metabolic_rate) calculations,
to determine how much energy a person needs,
but I'm willing to just ball-park it.
For an person not doing much exercise [Nutrition Australia says](http://www.nutritionaustralia.org/national/resource/balancing-energy-and-out) roughly says between 7,000Kj and 11,000Kj.
Using their calculator for my friend who is working out tons,
says up to 15,000Kj.
So lets say between 8,000Kj and 15,000Kj.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);

@constraint(m,
    7_000 <=
        total_intake("Energy, with dietary fibre (kJ)", diet)
    <= 15_000
    )

@objective(m, Max,  
    total_intake("Protein (g)", diet)
)
@show status = solve(m)
show_diet(diet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
   17 grams 	Fibre
   10 grams 	Folic acid
   >0 grams 	Vitamin C
 2353 grams 	Tea, regular, white, brewed from leaf or teabags, with cows milk not further defined
 2913 grams 	Milk & water, skim cow's milk & tap water
   20 grams 	Oil, safflower
  125 grams 	Egg, chicken, white (albumen) only, fried, no added fat
  332 grams 	Beef, rump steak, fully-trimmed, raw
  539 grams 	Pork, topside steak, untrimmed, baked, roasted, fried, grilled or BBQ'd, no added fat
   52 grams 	Kangaroo, rump, raw
   61 grams 	Coconut, milk, canned, not further defined
  151 grams 	Amino acid or creatine powder
  228 grams 	Lolly, non-mint flavours, intense sweetened
  296 grams 	Mixed vegetables, Asian greens, boiled, microwaved or steamed, drained

{% endhighlight %}
</div>

## Diet 7: Minimize Weight

What is the least weight of food we can be carrying while hiking?
We'll up the minimum energy to take into account the high expenditure,
and remove the cap on it (since weight alone can constrol our upper bound)

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
m, diet = new_diet()
basic_nutrient_requirements(m, diet);

@constraint(m,
    10_000 <= total_intake("Energy, with dietary fibre (kJ)", diet)
    )

#@constraint(m, total_intake("Moisture (g)", diet) <= 0.70sum(diet)*100) # Less than 25% liquid

@objective(m, Min,  sum(diet))
@show status = solve(m)
show_diet(diet)

println("Total: $(round(Int, 100sum(getvalue(diet)))) grams")
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
status = solve(m) = :Optimal
    2 grams 	Salt substitute, potassium chloride
    8 grams 	Fibre
   97 grams 	Biscuit, savoury, rice cracker, from brown rice, all flavours
   98 grams 	Breakfast cereal, mixed grain (rice & wheat), flakes, added vitamins B1, B2, B3, B6 & folate, Ca, Fe & Zn
    9 grams 	Oil, safflower
    3 grams 	Shortening, commercial, vegetable fat (for coatings, creams, icings, confectionery & fillings)
    1 grams 	Nut, brazil, with or without skin, raw, unsalted
   25 grams 	Protein powder, protein 45%, reduced sugars, fortified
    2 grams 	Protein powder, protein 20%, fortified, caffeinated
  157 grams 	Potato crisps or chips, plain, unsalted
   37 grams 	Intense sweetener, containing aspartame/acesulfame-potassium, tablet
   58 grams 	Sugar, white, with added stevia, granulated
    3 grams 	Seaweed, nori, dried
Total: 501 grams

{% endhighlight %}
</div>

This is actually fairly inline with the [kind of stuff intense hikers eat](http://blackwoodspress.com/blog/5521/10-ultralight-backpacking-foods/).
Nuts (well nut, singular), crisps, protein powder, cereal.

The trick in here seems to be the use of Breakfast serial, to hit most nutient requirements,
the Seweed/ nori to cover a whole bunch more, 
and then abusing the actual contents of additives and subsitutes  like acesulfame-potassium and stevia, to hit the others.

## Conclusion
One can go a long way with just linear programming.
To go a bit further (e.g. mimize the number of things, or (if you had the data) require nonfactional amounts of fruit etc), you'ld need mixed integer programming.
JuMP makes both easy; and with this number of variables even the NP-Hard mixed iteger programming can be solved in fairly reasonable time using the free solvers.

I'll conclude with another disclaimer: please don't try using diets you've made up based on constraints you've found online, and solved using linear programming.
I do not want to know what actually happens when someone eats 42Kg of powdered sweetener.

Still I hope this has been illustrative of the power of constrained optimization.
In general if  one can often transform problem into linear programming (Not technically, but effectively P),
or mixed integer programming (NP-hard),
that is a generally a short path to solving it.
Unless you've screwed up, such a formulation will likely correspond to the algorithm of minimum known time complexity for your problem.

