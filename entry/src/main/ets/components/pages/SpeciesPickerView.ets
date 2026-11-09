import { BirdSpecies } from '../../models/BirdModels';
import { PageHeaderView } from './PageHeaderView';

const BG = '#F9FAF7';
const WHITE = '#FFFFFF';
const INK = '#1C241F';
const MUTED = '#5E6861';
const BORDER = '#DDE3DC';
const GREEN = '#2F6B4F';

@Component
export struct SpeciesPickerView {
  @Link keyword: string;
  @Prop selectedSpeciesId: string;
  @Prop species: BirdSpecies[];
  @Prop speciesImages: Resource[];
  @BuilderParam onBack: () => void;
  @BuilderParam onSelect: (speciesId: string) => void;

  build() {
    Column() {
      PageHeaderView({ title: '选择鸟种', onBack: () => this.onBack() })
      Column({ space: 12 }) {
        TextInput({ text: this.keyword, placeholder: '搜索中文名、别名或学名' }).height(48).fontColor(INK).placeholderColor(MUTED).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onChange((value: string) => this.keyword = value)
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.species, (item: BirdSpecies, index: number) => {
              Row({ space: 12 }) {
                Image(this.speciesImages[index]).width(58).height(58).objectFit(ImageFit.Cover).borderRadius(6)
                Column({ space: 2 }) { Text(item.name).fontFamily('serif').fontSize(17).fontColor(INK); Text(item.scientificName).fontFamily('serif').fontSize(12).fontColor(MUTED) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.selectedSpeciesId === item.id ? '✓' : '›').fontColor(GREEN)
              }.padding(12).backgroundColor(WHITE).border({ width: 1, color: BORDER }).borderRadius(8).onClick(() => this.onSelect(item.id))
            }, (item: BirdSpecies) => item.id)
          }
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.padding({ left: 16, right: 16, bottom: 18 }).layoutWeight(1)
    }.backgroundColor(BG)
  }
}
