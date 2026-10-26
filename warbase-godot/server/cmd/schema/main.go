// Prints the wire-compatible FPS schema embedded in the current generated codec.
package main
import("fmt";"warbase-server/internal/engine";"google.golang.org/protobuf/reflect/protoreflect")
func field(f protoreflect.FieldDescriptor) {
 typ:=f.Kind().String(); if f.Message()!=nil {typ=string(f.Message().Name())}
 prefix:="";if f.IsList(){prefix="repeated "}
 if f.IsMap(){typ=fmt.Sprintf("map<%s, %s>",f.MapKey().Kind(),f.MapValue().Message().Name());prefix=""}
 fmt.Printf("    %s%s %s = %d;\n",prefix,typ,f.Name(),f.Number())
}
func main(){
 fmt.Println("syntax = \"proto3\";\npackage warbase;\noption go_package = \"warbase-server/internal/engine\";")
 messages:=engine.File_packets_proto.Messages()
 for i:=0;i<messages.Len();i++ {m:=messages.Get(i);fmt.Printf("\nmessage %s {\n",m.Name());fields:=m.Fields()
 for j:=0;j<fields.Len();j++{f:=fields.Get(j);if f.ContainingOneof()==nil{field(f)}}
 oneofs:=m.Oneofs();for j:=0;j<oneofs.Len();j++{o:=oneofs.Get(j);fmt.Printf("  oneof %s {\n",o.Name());for k:=0;k<o.Fields().Len();k++{field(o.Fields().Get(k))};fmt.Println("  }")};fmt.Println("}")}
}
