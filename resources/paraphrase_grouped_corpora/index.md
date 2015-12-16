---
layout: default
title: Paraphrase Grouped Corpora

---

These corpora have been prepared by taking existing real-word based corpora: The Microsoft Research Paraphrase Corpus, and Opinosis, and partitioning them into  groups of sentences which all share the same meaning.

Use of either of these should cite the paper:

```
	@inproceedings{White:2015:WSE:2838931.2838932,
	 author = {White, Lyndon and Togneri, Roberto and Liu, Wei and Bennamoun, Mohammed},
	 title = {How Well Sentence Embeddings Capture Meaning},
	 booktitle = {Proceedings of the 20th Australasian Document Computing Symposium},
	 series = {ADCS '15},
	 year = {2015},
	 isbn = {978-1-4503-4040-3},
	 location = {Parramatta, NSW, Australia},
	 pages = {9:1--9:8},
	 articleno = {9},
	 numpages = {8},
	 url = {http://doi.acm.org/10.1145/2838931.2838932},
	 doi = {10.1145/2838931.2838932},
	 acmid = {2838932},
	 publisher = {ACM},
	 address = {New York, NY, USA},
	 keywords = {Semantic vector space representations, semantic consistency evaluation, sentence embeddings, word embeddings},
	}
```

-----

##Opinosis

[Download](./opinosis_paraphrase_grouped.zip)

A subset of the Opinosis corpus was manually grouped according to its meaning.

The original Opinosis corpus can be obtained by following [this link](http://kavita-ganesan.com/opinosis-opinion-dataset)

This dervived corpus is redistributed by permission of the orignal corpus creator.

Use of the derived corpus here should cite the paper detailing the original corpus:

```
    @inproceedings{ganesan2010opinosis,
      title={Opinosis: a graph-based approach to abstractive summarization of highly redundant opinions},
      author={Ganesan, Kavita and Zhai, ChengXiang and Han, Jiawei},
      booktitle={Proceedings of the 23rd International Conference on Computational Linguistics},
      pages={340--348},
      year={2010},
      organization={Association for Computational Linguistics}
    }

```


##MSRP

[Download](./msrp_paraphrase_grouped.zip)

A subset of the Microsoft Reseach Paraphrase corpus was automatically grouped according to its original manually annotated meaning. This was done by taking the symetric and transitive closure over the original set of paraphrase pairs.

The original MSRP corpus can be obtained by following [this link](http://research.microsoft.com/en-us/downloads/607d14d9-20cd-47e3-85bc-a2f65cd28042/)

This derived corpus is redistributed under the [MSR-SSLA](http://research.microsoft.com/en-us/downloads/607d14d9-20cd-47e3-85bc-a2f65cd28042/License.txt).

Use of the derived corpus here should cite the paper detailing the original corpus:

```
    @inproceedings{dolan2004unsupervised,
        title={Unsupervised construction of large paraphrase corpora: Exploiting massively parallel news sources},
        author={Dolan, Bill and Quirk, Chris and Brockett, Chris},
        booktitle={Proceedings of the 20th international conference on Computational Linguistics},
        pages={350},
        year={2004},
        organization={Association for Computational Linguistics}
    }

```



