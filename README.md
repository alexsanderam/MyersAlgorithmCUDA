Tópicos Especiais em Programação de Computadores - TM418 - 2014.02
Bacharelado em Ciência da Computação, Universidade Federal Rural do Rio de Janeiro

Professor: Marcelo Zamith

Alunos: Alexsander Andrade de Melo e Ygor de Mello Canalli

Descrição:

Este trabalho baseia-se no artigo Thread-cooperative, Bit-parallel Computation of Levenshtein Distance on GPU de Chacón et al. [1], no qual é apresentado duas estratégias de paralelismo em GPU para o problema de String Matching utilizando o algoritmo de Myers [2], a saber: uma estratégia inter-tarefa, ou seja, paralelismo a nı́vel de tarefa (Task-parallel ) e outra intra-tarefa (Thread-cooperative). Neste traballho propomos uma estratégia Thread-cooperative diferente da abordada em [1], onde obtemos uma melhora de até 3 375% (33,75x) se comparado aos resultados obtidos na execução sequencial em CPU.

[1] Chacón, A., Marco-Sola, S., Espinosa, A., Ribeca, P., e Moure, J. C. Thread-cooperative, bit-parallel computation of levenshtein distance on gpu. In Proceedings of the 28th ACM International Conference on Supercomputing (New York, NY, USA, 2014), ICS ’14, ACM, pp. 103–112.

[2] Myers, G. A fast bit-vector algorithm for approximate string matching based on dynamic programming. J. ACM 46, 3 (maio de 1999), 395–415.

