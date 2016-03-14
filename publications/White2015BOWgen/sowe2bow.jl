#MIT License (MIT)
#Copyright (c) 2016 Lyndon White
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



"""
# data is a dictionary containing the fields:
# LL ::Matrix -- every column is a word-embedding
# word_indexes ::Dict{S,Int} -- maps words to their index
# word_indexes ::Vector{S} -- map indecies back to their words
"""
module sowe2bow

export greedy_search,lookup_sowe

function lookup_sowe(data, sent)
    lookup_sowe(data, sent |> split)
end

function lookup_sowe{S}(data, sent::Vector{S})
    sum([data["LL"][:,data["word_indexes"][word]] for word in sent]) 
end

function lookup_words(data, path)
    ASCIIString[data["indexed_words"][ii] for ii in path]
end

function lookup_indexes{S}(data, sent::Vector{S})
    Int[data["word_indexes"][word] for word in sent]
end



#ϵ constance used for round off when comparing fitness scores -- floats that are closer than ϵ appart are considered the same value
#Numeric (in-)stability causes differences between the value reported by `fitness`, and `score_possible_additions` even for the same total chain of words
const ϵ = 10.0^-5

"""
LL: Matrix of all word vectors
ws: the current bag of word vectors, expressed a vector of indexes
"""
@inline function get_end(LL, ws::AbstractVector{Int})
    @inbounds sofar = length(ws)>0 ? sum([sub(LL,(:,ii)) for ii in ws]) : zeros(size(LL,1))
    sofar
end

"""
Scores all possible additions.
This method is significant
target: the vector they need to sum to in the end
end_point: the sum of the word vectors in the bag so far (returned by get_end)
"""
function score_possible_additions(LL, target, end_point)
    #-(sumabs(LL.+(end_point.-target),1)) #City Block
    -sqrt(sumabs2(LL.+(end_point.-target),1)) #Euclidean
    
end   

"""
Evaluates distance from the end_point vector to the target vector
target: the vector they need to sum to in the end
end_point: the sum of the word vectors in the bag so far (returned by get_end)
"""
@inline function fitness(target, end_point)
    #Fitter is larger
    #-sumabs(end_point.-target) #city block
    -norm(end_point.-target) #euclidean
    
end

"""
Performed the greed addition step to find the bag of words from a sum of word embeddings
LL: Matrix of all word vectors
target: the vector they need to sum to in the end
initial_word_set: the initial bag of word vectors, expressed a vector of indexes. Can be an empty vector
max_additions: THe maximum number of additions to perform, normally infinite, but for certain variations on this step (including n-subsitution) can beset to an integer
"""
function greedy_addition{F<:AbstractFloat}(LL::Matrix{F},
                         target::Vector{F},
                         initial_word_set::AbstractVector{Int},
                         max_additions = Inf)
    best_word_set = convert(Vector{Int},initial_word_set)
    end_point = get_end(LL, best_word_set)
    best_score = fitness(target, end_point)
    
    cur_additions = 0
    while(cur_additions<max_additions)   
        cur_additions+=1
        addition_scores = score_possible_additions(LL, target, end_point)
        addition_score, addition = findmax(addition_scores)
        if addition_score>best_score+ϵ
            #println("!add: $addition $best_score")
            best_score=addition_score
            push!(best_word_set, addition)
            end_point += sub(LL,(:,addition))
        else 
            break
        end
    end
    best_word_set,best_score
end

"""
Performed the 1-subsitution step to refine the bag of words for a sum of word embeddings.
Ie considered swapping any one word with a different word, or with removing it entirely
LL: Matrix of all word vectors
target: the vector they need to sum to in the end
initial_word_set: the initial bag of word vectors, expressed a vector of indexes. Normally the result of performing greedy addition. This should not be en empty set -- then there would be nothing to refine.
"""
function word_swap_refinement{F<:AbstractFloat}(LL::Matrix{F},
                              target::Vector{F},
                              initial_word_set::AbstractVector{Int})
    
    best_word_set = copy(initial_word_set)
    end_point = get_end(LL, initial_word_set)
    best_score = fitness(target, end_point)
    function update_best!(word_set,score)
        if score>best_score+ϵ #scores are negative
            best_score=score
            best_word_set = word_set
            #println("*swap, new set: $word_set $score")
        end
    end
    n_words_initial = length(initial_word_set)
    for ii in 1:n_words_initial-1 #Don't need to consider last word added as it was added greedily
        word_set = sub(initial_word_set,[1:ii-1; ii+1:n_words_initial])
        sub_endpoint = end_point - sub(LL,(:,initial_word_set[ii]))
        subset_score = fitness(target, sub_endpoint) #Try just removing (without replacement)
        update_best!(word_set, subset_score)
        

        add_word_set, add_score = greedy_addition(LL, target, word_set, 1) #Try adding just one greedily
        update_best!(add_word_set, add_score)
    end

    best_word_set,best_score
        
end

"""
Performse the entire process of Greedy addition, followed by 1-substutitution, repeated until convergence.
data: a Dictionary of word embedding informantion
target: the sum of word embeddings that is trying to be reached during recovery
rounds: A maximumn number of rounds of Greedy addition then 1-substution to be done -- normally set arbitarily high, limitting it is useful for debugging numerical stability, and investigating time per round.
log: set to try to display logging messages
Returns a bag of words, represented as a vector of strings, and the score of how close it was to the target -- perfect is 0.
"""
function greedy_search{F<:AbstractFloat}(data::Dict, target::Vector{F}; rounds=1000, log=false)
    get_words(word_iis) = [data["indexed_words"][ii] for ii in word_iis]
    
    word_iis = Int[]
    best_word_iis = word_iis
    best_score=-Inf
    for round in 1:rounds
        word_iis, add_score = greedy_addition(data["LL"], target, word_iis)
        log && println("POST_ADD_STEP: $add_score $(get_words(word_iis))")
        @assert add_score + ϵ >= best_score || best_word_iis == word_iis "$add_score vs $best_score $(get_words(word_iis))"
        best_word_iis = word_iis
        
        if add_score>= 0.0 
            best_score = add_score
            break 
        end        
        
        
        word_iis, swap_score = word_swap_refinement(data["LL"], target, word_iis)
        log && println("POST_SWAP_STEP: $swap_score $(get_words(word_iis))")
        @assert swap_score + ϵ >= add_score || best_word_iis == word_iis
        best_word_iis = word_iis
        
        converged = best_score - ϵ<swap_score<best_score + ϵ || swap_score>=-ϵ
        best_score=swap_score
        if converged
            break 
        end       
    end
    get_words(word_iis),best_score
end


end #End Module
