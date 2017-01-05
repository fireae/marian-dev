#include <algorithm>
#include <chrono>
#include <iomanip>
#include <string>
#include <cstdio>
#include <boost/timer/timer.hpp>

#include "marian.h"
#include "nematus.h"
#include "batch_generator.h"
#include "optimizers.h"

#include "corpus.h"

int main(int argc, char** argv) {
  using namespace marian;
  using namespace data;

  cudaSetDevice(0);

  std::vector<std::string> files = {"../test/mini.de", "../test/mini.en"};
  std::vector<std::string> vocab = {"../test/vocab.de.json", "../test/vocab.en.json"};

  auto corpus = DataSet<Corpus>(files, vocab);
  BatchGenerator<Corpus> bg(corpus, 10, 1000);

  bg.prepare();
  auto batch = bg.next();
  batch->test();

  auto nematus = New<Nematus>();
  nematus->reserveWorkspaceMB(2048);
  //nematus->load("../test/model.npz");

  auto opt = Optimizer<Adam>(0.0001
                             /*,clip=norm(1)*/);

  size_t batchSize = 3;
  float sum = 0;
  boost::timer::cpu_timer timer;
  for(int i = 1; i <= 2000; ++i) {

    // fake batch
    auto srcBatch = generateSrcBatch(batchSize);
    auto trgBatch = generateTrgBatch(batchSize);
    nematus->construct(srcBatch, trgBatch);

    opt->update(nematus);

    float cost = nematus->cost();
    sum += cost;

    //if(i % 1 == 0)
    //  std::cerr << ".";
    if(i % 1 == 0)
      std::cout << "[" << i << "]" << std::fixed << std::setfill(' ') << std::setw(9)
                << " - cost: " << cost << "/" << sum / i
                << " - time: " << timer.format(5, "%ws") << std::endl;
  }
  std::cout << std::endl;
  std::cout << timer.format(5, "%ws") << std::endl;

  nematus->save("../test/model.marian.npz");

  return 0;
}